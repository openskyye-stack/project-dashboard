import Foundation

/// Chooses recipes and turns a week's plan into a shopping list and a batch-prep
/// session.
enum MealPlanner {

    // MARK: - Filtering

    struct Filter {
        var tier: ChallengeTier? = nil
        var dietary: [DietaryPreference] = []
        var slot: MealSlot? = nil
        var maxStandingMinutes: Int? = nil
        var requiresSeatedPrep: Bool = false
        var requiresOneHanded: Bool = false
        var requiresSoftTexture: Bool = false
        var batchOnly: Bool = false
        var maxTotalMinutes: Int? = nil
        var searchText: String = ""

        static let none = Filter()
    }

    /// Builds the filter that matches this person's constraints by default, so
    /// the recipe list opens on things they can actually cook.
    static func defaultFilter(for profile: UserProfile, tier: ChallengeTier?) -> Filter {
        var filter = Filter()
        filter.tier = tier
        filter.dietary = profile.dietary.filter { $0 != .none }

        // Someone who can stand for 10 minutes should not be shown a recipe that
        // needs 25 minutes at the hob.
        if profile.mobility != .unrestricted || profile.continuousStandingMinutes < 20 {
            filter.maxStandingMinutes = max(5, profile.continuousStandingMinutes)
        }
        if profile.mobility == .seated {
            filter.requiresSeatedPrep = true
        }
        if profile.dietary.contains(.softTexture) {
            filter.requiresSoftTexture = true
        }
        return filter
    }

    static func apply(_ filter: Filter, to recipes: [Recipe]) -> [Recipe] {
        recipes.filter { recipe in
            if let tier = filter.tier, !recipe.tierCompliance.isEmpty, !recipe.satisfies(tier: tier) { return false }
            if let slot = filter.slot, recipe.mealSlot != slot { return false }
            if !recipe.suits(dietary: filter.dietary) { return false }
            if let cap = filter.maxStandingMinutes, recipe.standingMinutes > cap { return false }
            if filter.requiresSeatedPrep && !recipe.seatedPrepFriendly { return false }
            if filter.requiresOneHanded && !recipe.oneHandedFriendly { return false }
            if filter.requiresSoftTexture && !recipe.softTexture { return false }
            if filter.batchOnly && !recipe.batchFriendly { return false }
            if let cap = filter.maxTotalMinutes, recipe.totalMinutes > cap { return false }

            let query = filter.searchText.trimmingCharacters(in: .whitespaces).lowercased()
            if !query.isEmpty {
                let haystack = (recipe.title + " " + recipe.summary).lowercased()
                if !haystack.contains(query) { return false }
            }
            return true
        }
    }

    // MARK: - Automatic week

    struct PlannedMeal {
        var date: Date
        var slot: MealSlot
        var recipe: Recipe
        var servings: Int
    }

    /// Fills seven days of breakfast, lunch and dinner, favouring batch-friendly
    /// recipes so the week takes two cooking sessions rather than twenty-one.
    static func generateWeek(
        startingOn start: Date,
        recipes: [Recipe],
        profile: UserProfile,
        tier: ChallengeTier,
        includeSnack: Bool = true
    ) -> [PlannedMeal] {
        let calendar = Calendar.current
        let filter = defaultFilter(for: profile, tier: tier)
        let pool = apply(filter, to: recipes)

        // Fall back to the unfiltered set rather than producing an empty week.
        func candidates(for slot: MealSlot) -> [Recipe] {
            let filtered = pool.filter { $0.mealSlot == slot }
            if !filtered.isEmpty { return filtered }
            let relaxed = recipes.filter { $0.mealSlot == slot && $0.suits(dietary: filter.dietary) }
            return relaxed.isEmpty ? recipes.filter { $0.mealSlot == slot } : relaxed
        }

        var planned: [PlannedMeal] = []
        var slots: [MealSlot] = [.breakfast, .lunch, .dinner]
        if includeSnack { slots.append(.snack) }

        for slot in slots {
            let options = candidates(for: slot).sorted { lhs, rhs in
                // Batch-friendly first, then least standing, then most protein.
                if lhs.batchFriendly != rhs.batchFriendly { return lhs.batchFriendly }
                if lhs.standingMinutes != rhs.standingMinutes { return lhs.standingMinutes < rhs.standingMinutes }
                return lhs.proteinPerServing > rhs.proteinPerServing
            }
            guard !options.isEmpty else { continue }

            var dayIndex = 0
            var optionIndex = 0
            while dayIndex < 7 {
                let recipe = options[optionIndex % options.count]
                // A batch recipe covers as many days as it makes servings, up to
                // four — beyond that it stops being appetising.
                let span = recipe.batchFriendly ? min(4, max(1, recipe.servings), 7 - dayIndex) : 1

                for offset in 0..<span {
                    guard let date = calendar.date(byAdding: .day, value: dayIndex + offset, to: start) else { continue }
                    planned.append(PlannedMeal(date: date, slot: slot, recipe: recipe, servings: 1))
                }
                dayIndex += span
                optionIndex += 1
            }
        }
        return planned
    }

    // MARK: - Shopping list

    /// Aggregates every planned meal into one list, merging identical
    /// ingredients and scaling by how many servings are actually planned.
    static func buildShoppingList(
        from entries: [MealPlanEntry],
        recipes: [Recipe],
        weekStart: Date
    ) -> [ShoppingItem] {
        let byID = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })

        struct Accumulator {
            var name: String
            var quantity: Double
            var unit: String
            var aisle: GroceryAisle
            var sources: Set<String>
        }

        var merged: [String: Accumulator] = [:]

        for entry in entries {
            guard let recipe = byID[entry.recipeID] else { continue }
            let scale = recipe.servings > 0 ? Double(entry.servings) / Double(recipe.servings) : 1

            for line in recipe.ingredients where !line.isOptional {
                let key = line.mergeKey
                let scaled = line.quantity * scale
                if var existing = merged[key] {
                    existing.quantity += scaled
                    existing.sources.insert(recipe.title)
                    merged[key] = existing
                } else {
                    merged[key] = Accumulator(
                        name: line.name,
                        quantity: scaled,
                        unit: line.unit,
                        aisle: line.aisle,
                        sources: [recipe.title]
                    )
                }
            }
        }

        return merged.values
            .map { accumulator in
                ShoppingItem(
                    name: accumulator.name,
                    // Round up: half an onion is still one onion at the till.
                    quantity: roundUpForShopping(accumulator.quantity, unit: accumulator.unit),
                    unit: accumulator.unit,
                    aisle: accumulator.aisle,
                    sourceRecipes: accumulator.sources.sorted(),
                    weekStart: weekStart
                )
            }
            .sorted { lhs, rhs in
                if lhs.aisle.walkOrder != rhs.aisle.walkOrder {
                    return lhs.aisle.walkOrder < rhs.aisle.walkOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private static func roundUpForShopping(_ quantity: Double, unit: String) -> Double {
        // Weight and volume can stay fractional; countable things round up.
        let measured: Set<String> = ["g", "kg", "ml", "l", "oz", "lb", "tbsp", "tsp", "cup", "cups"]
        if measured.contains(unit.lowercased()) {
            return (quantity * 10).rounded() / 10
        }
        return quantity.rounded(.up)
    }

    // MARK: - Batch prep session

    struct PrepStep: Identifiable {
        var id: String { "\(order)-\(title)" }
        var order: Int
        var title: String
        var detail: String
        var minutes: Int
        var isSeated: Bool
    }

    /// Turns the week's batch recipes into an ordered prep session with the
    /// long-cooking items first and all the seated work grouped together, so
    /// standing time comes in one predictable block instead of scattered.
    static func prepSession(for entries: [MealPlanEntry], recipes: [Recipe], profile: UserProfile) -> [PrepStep] {
        let byID = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
        let unique = Set(entries.map(\.recipeID)).compactMap { byID[$0] }
        let batch = unique.filter(\.batchFriendly)

        guard !batch.isEmpty else { return [] }

        var steps: [PrepStep] = []
        var order = 1

        // 1. Longest cook goes on first so it runs while you do everything else.
        for recipe in batch.sorted(by: { $0.cookMinutes > $1.cookMinutes }) where recipe.cookMinutes >= 20 {
            steps.append(PrepStep(
                order: order,
                title: "Start \(recipe.title)",
                detail: "Longest cook in the session — get it going first. \(recipe.cookMinutes) minutes unattended.",
                minutes: max(5, recipe.prepMinutes),
                isSeated: recipe.seatedPrepFriendly
            ))
            order += 1
        }

        // 2. All the chopping in one seated block.
        let choppers = batch.filter { !$0.lowKnifeSkill }
        if !choppers.isEmpty {
            steps.append(PrepStep(
                order: order,
                title: "Chop everything, sitting down",
                detail: "Bring a board and bowls to the table. Covers \(choppers.map(\.title).joined(separator: ", ")).",
                minutes: choppers.reduce(0) { $0 + $1.prepMinutes / 2 },
                isSeated: true
            ))
            order += 1
        }

        // 3. Short-cook items.
        for recipe in batch.filter({ $0.cookMinutes < 20 }) {
            steps.append(PrepStep(
                order: order,
                title: "Assemble \(recipe.title)",
                detail: "\(recipe.servings) servings. \(recipe.standingMinutes) minutes on your feet.",
                minutes: recipe.totalMinutes,
                isSeated: recipe.seatedPrepFriendly
            ))
            order += 1
        }

        // 4. Portion and label.
        steps.append(PrepStep(
            order: order,
            title: "Portion and label",
            detail: "Containers on the table, date each lid. This is the step people skip and then eat toast on Thursday.",
            minutes: 10,
            isSeated: true
        ))

        // Insert a rest break for anyone who told us standing is limited.
        if profile.continuousStandingMinutes < 25 {
            var withBreaks: [PrepStep] = []
            var standingRun = 0
            var counter = 1
            for step in steps {
                withBreaks.append(PrepStep(order: counter, title: step.title, detail: step.detail, minutes: step.minutes, isSeated: step.isSeated))
                counter += 1
                standingRun = step.isSeated ? 0 : standingRun + step.minutes
                if standingRun >= profile.continuousStandingMinutes {
                    withBreaks.append(PrepStep(
                        order: counter,
                        title: "Sit down for five minutes",
                        detail: "You've been on your feet for about \(standingRun) minutes. The food will wait.",
                        minutes: 5,
                        isSeated: true
                    ))
                    counter += 1
                    standingRun = 0
                }
            }
            return withBreaks
        }

        return steps
    }
}
