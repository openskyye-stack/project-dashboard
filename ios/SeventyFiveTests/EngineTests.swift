import Testing
import Foundation
@testable import SeventyFive

// MARK: - Fixtures

private func makeProfile(
    age: Int = 45,
    weightKg: Double = 80,
    mobility: MobilityLevel = .unrestricted,
    pain: PainLevel = .none,
    considerations: [HealthConsideration] = [],
    minutesPerDay: Int = 120,
    standingMinutes: Int = 45,
    balance: Int = 4,
    fallen: Bool = false,
    outdoor: OutdoorAccess = .easy
) -> UserProfile {
    let profile = UserProfile()
    profile.birthYear = Calendar.current.component(.year, from: Date()) - age
    profile.weightKg = weightKg
    profile.mobility = mobility
    profile.jointPain = pain
    profile.considerations = considerations
    profile.availableMinutesPerDay = minutesPerDay
    profile.continuousStandingMinutes = standingMinutes
    profile.balanceConfidence = balance
    profile.hasFallenInLastYear = fallen
    profile.outdoorAccess = outdoor
    return profile
}

// MARK: - Hydration

@Suite("Hydration targets")
struct HydrationTests {

    @Test("A fixed gallon is never imposed on a small, older body")
    func olderSmallPersonGetsLessThanAGallon() {
        let profile = makeProfile(age: 78, weightKg: 55)
        let result = HydrationCalculator.dailyTarget(for: profile, tier: .hard)

        // A US gallon is 3785 ml. 55 kg at 31 ml/kg is ~1705, +15% for Hard.
        #expect(result.targetML < 2500)
        #expect(result.targetML >= 1000)
    }

    @Test("Fluid-restricted people are capped hard and told to ask a clinician")
    func fluidRestrictionCaps() {
        let profile = makeProfile(age: 70, weightKg: 90, considerations: [.heartFailure])
        let result = HydrationCalculator.dailyTarget(for: profile, tier: .hard)

        #expect(result.targetML <= HydrationCalculator.restrictedCeilingML)
        #expect(result.isCapped)
        #expect(result.requiresClinicianInput)
    }

    @Test("Nobody is ever asked for more than four litres")
    func absoluteCeilingHolds() {
        let profile = makeProfile(age: 30, weightKg: 200)
        let result = HydrationCalculator.dailyTarget(for: profile, tier: .hard)
        #expect(result.targetML <= HydrationCalculator.absoluteCeilingML)
    }

    @Test("Targets land on whole 250 ml glasses")
    func targetsAreGlassAligned() {
        for weight in stride(from: 45.0, through: 140.0, by: 5.0) {
            let profile = makeProfile(weightKg: weight)
            let result = HydrationCalculator.dailyTarget(for: profile, tier: .medium)
            #expect(result.targetML.truncatingRemainder(dividingBy: 250) == 0)
        }
    }

    @Test("Reminders stop before wind-down")
    func remindersRespectWindDown() {
        let profile = makeProfile()
        profile.preferredStartHour = 7
        profile.preferredWindDownHour = 21
        let hours = HydrationCalculator.reminderHours(for: profile, glassCount: 12)

        #expect(hours.allSatisfy { $0 >= 7 && $0 <= 19 })
        #expect(hours.count >= 3)
    }
}

// MARK: - Tier engine

@Suite("Rule generation")
struct TierEngineTests {

    @Test("An unrestricted adult on Hard gets the classic two sessions")
    func hardKeepsTwoSessions() {
        let profile = makeProfile(age: 30, minutesPerDay: 150)
        let rules = TierEngine.buildRules(tier: .hard, profile: profile)

        #expect(rules.rule(id: "workout.primary") != nil)
        #expect(rules.rule(id: "workout.secondary") != nil)
        #expect(rules.rule(id: "workout.primary")?.target == 45)
    }

    @Test("Workout length shrinks with age and pain but never below fifteen minutes")
    func durationsScaleDownWithAFloor() {
        let young = makeProfile(age: 30)
        let old = makeProfile(age: 82, pain: .severe, minutesPerDay: 60)

        let youngTarget = TierEngine.buildRules(tier: .hard, profile: young).rule(id: "workout.primary")?.target ?? 0
        let oldTarget = TierEngine.buildRules(tier: .hard, profile: old).rule(id: "workout.primary")?.target ?? 0

        #expect(oldTarget < youngTarget)
        #expect(oldTarget >= 15)
    }

    @Test("The plan never exceeds the time the person said they have")
    func planFitsTheTimeBudget() {
        let profile = makeProfile(age: 60, minutesPerDay: 60)
        let rules = TierEngine.buildRules(tier: .hard, profile: profile)

        let movement = rules.rules
            .filter { $0.unit == .minutes }
            .reduce(0.0) { $0 + $1.target }

        #expect(movement <= Double(profile.availableMinutesPerDay))
    }

    @Test("Short standing tolerance splits the session into chunks")
    func shortStandingSplitsSessions() {
        let profile = makeProfile(age: 68, standingMinutes: 10)
        let rules = TierEngine.buildRules(tier: .medium, profile: profile)
        let primary = rules.rule(id: "workout.primary")

        #expect((primary?.maxSplits ?? 1) > 1)
    }

    @Test("Balance work is added for older users and fall risks, and never for a fit thirty-year-old")
    func balanceWorkAppearsWhenItShould() {
        let older = makeProfile(age: 72)
        let faller = makeProfile(age: 40, fallen: true)
        let young = makeProfile(age: 30)

        #expect(TierEngine.buildRules(tier: .medium, profile: older).rule(id: "balance.daily") != nil)
        #expect(TierEngine.buildRules(tier: .medium, profile: faller).rule(id: "balance.daily") != nil)
        #expect(TierEngine.buildRules(tier: .medium, profile: young).rule(id: "balance.daily") == nil)
    }

    @Test("Every adapted rule explains itself")
    func adaptationsAreExplained() {
        let profile = makeProfile(age: 78, pain: .moderate, standingMinutes: 10, minutesPerDay: 60)
        let rules = TierEngine.buildRules(tier: .hard, profile: profile)
        let primary = rules.rule(id: "workout.primary")

        #expect(!(primary?.adaptations.isEmpty ?? true))
    }

    @Test("Audiobook readers get minutes rather than pages")
    func audiobookConvertsUnits() {
        let profile = makeProfile()
        profile.readingFormat = .audiobook
        let rules = TierEngine.buildRules(tier: .medium, profile: profile)

        #expect(rules.rule(id: "reading")?.unit == .minutes)
    }

    @Test("Someone with no outdoor access still gets a second session, indoors")
    func outdoorRuleIsRewrittenNotRemoved() {
        let profile = makeProfile(outdoor: .unsafeOrUnavailable)
        let rules = TierEngine.buildRules(tier: .hard, profile: profile)

        #expect(rules.rule(id: "workout.secondary") != nil)
        #expect(rules.rule(id: "workout.secondary")?.kind == .workout)
    }

    @Test("Recommendation is gentler for an older, less mobile person")
    func recommendationRespondsToProfile() {
        let fit = makeProfile(age: 28, minutesPerDay: 150)
        let frail = makeProfile(age: 80, mobility: .usesWalkingAid, pain: .moderate,
                                considerations: [.heartCondition], minutesPerDay: 45)

        #expect(TierEngine.recommendTier(for: fit).tier.intensityRank
                > TierEngine.recommendTier(for: frail).tier.intensityRank)
    }
}

// MARK: - Mobility

@Suite("Mobility adaptation")
struct MobilityTests {

    @Test("A wheelchair user is only offered seated options")
    func seatedUserGetsSeatedOptions() {
        let profile = makeProfile(mobility: .seated)
        let options = MobilityAdaptation.options(for: profile)

        #expect(!options.isEmpty)
        #expect(options.allSatisfy(\.isSeated))
    }

    @Test("Low-impact-only profiles never see impact work")
    func lowImpactFiltering() {
        let profile = makeProfile(pain: .moderate, considerations: [.osteoporosis])
        let options = MobilityAdaptation.options(for: profile)

        #expect(options.allSatisfy(\.isLowImpact))
    }

    @Test("Equipment gates options, but a chair is always assumed")
    func equipmentGating() {
        let profile = makeProfile()
        profile.equipment = []
        let options = MobilityAdaptation.options(for: profile)

        #expect(options.contains { $0.id == "chair.circuit" })
        #expect(!options.contains { $0.id == "pool" })
    }

    @Test("Fall risk moves the outdoor requirement to level ground")
    func fallRiskChangesOutdoorPolicy() {
        let faller = makeProfile(fallen: true)
        #expect(MobilityAdaptation.outdoorPolicy(for: faller) == .doorstepOrSheltered)

        let steady = makeProfile()
        #expect(MobilityAdaptation.outdoorPolicy(for: steady) == .fullyOutdoor)
    }
}

// MARK: - Day scaling

@Suite("Daily check-in scaling")
struct DayScalerTests {

    @Test("A good morning produces no scaling")
    func goodMorningIsFullPlan() {
        let outcome = DayScaler.evaluate(.neutral, profile: makeProfile())
        #expect(outcome.scaleFactor == 1.0)
    }

    @Test("High pain scales the day down and suggests rest")
    func highPainDeloads() {
        let checkIn = DayScaler.CheckIn(sleepHours: 5, painScore: 8, energyScore: 1, sorenessScore: 4)
        let outcome = DayScaler.evaluate(checkIn, profile: makeProfile(age: 70))

        #expect(outcome.scaleFactor < 0.7)
        #expect(outcome.suggestsRest)
    }

    @Test("Scaling never falls below the age-appropriate floor")
    func scalingHasAFloor() {
        let checkIn = DayScaler.CheckIn(sleepHours: 0, painScore: 10, energyScore: 1, sorenessScore: 5)
        let outcome = DayScaler.evaluate(checkIn, profile: makeProfile(age: 80))

        #expect(outcome.scaleFactor >= 0.5)
    }

    @Test("Water and yes/no rules are never scaled down")
    func hydrationIsNotScaled() {
        let hydration = TaskRule(id: "hydration", kind: .hydration, title: "Water",
                                 detail: "", target: 3000, unit: .milliliters)
        let diet = TaskRule(id: "nutrition", kind: .nutrition, title: "Diet",
                            detail: "", target: 1, unit: .yesNo)

        #expect(DayScaler.scaledTarget(for: hydration, scaleFactor: 0.5) == 3000)
        #expect(DayScaler.scaledTarget(for: diet, scaleFactor: 0.5) == 1)
    }

    @Test("Minute targets scale to a sensible round number")
    func minuteTargetsScaleCleanly() {
        let workout = TaskRule(id: "w", kind: .workout, title: "Workout",
                               detail: "", target: 40, unit: .minutes)
        let scaled = DayScaler.scaledTarget(for: workout, scaleFactor: 0.5)

        #expect(scaled == 20)
    }
}

// MARK: - Gamification

@Suite("XP, levels and streaks")
struct ProgressEngineTests {

    @Test("Levels increase monotonically with XP")
    func levelsAreMonotonic() {
        var lastIndex = 0
        for xp in stride(from: 0, through: 12000, by: 100) {
            let level = XPEngine.level(for: xp)
            #expect(level.index >= lastIndex)
            lastIndex = level.index
        }
    }

    @Test("Streak multiplier grows but stays bounded")
    func multiplierIsBounded() {
        #expect(XPEngine.streakMultiplier(streak: 0) == 1.0)
        #expect(XPEngine.streakMultiplier(streak: 100) <= 2.0)
        #expect(XPEngine.streakMultiplier(streak: 30) > XPEngine.streakMultiplier(streak: 5))
    }

    @Test("Hard tier offers no grace days; soft tier never forces a restart")
    func missPoliciesMatchTiers() {
        #expect(ChallengeTier.hard.missPolicy == .restart)
        #expect(ChallengeTier.soft.missPolicy == .streakBreakOnly)
        if case .graceDays = ChallengeTier.medium.missPolicy {
            // expected
        } else {
            Issue.record("Medium tier should offer grace days")
        }
    }
}

// MARK: - Recipe import

@Suite("Recipe import")
struct RecipeImporterTests {

    @Test("ISO 8601 durations parse to minutes")
    func durationParsing() {
        #expect(RecipeImporter.minutes(from: "PT30M") == 30)
        #expect(RecipeImporter.minutes(from: "PT1H15M") == 75)
        #expect(RecipeImporter.minutes(from: "PT2H") == 120)
        #expect(RecipeImporter.minutes(from: "garbage") == 0)
    }

    @Test("Yields parse out of free text")
    func servingsParsing() {
        #expect(RecipeImporter.servings(from: "4 servings") == 4)
        #expect(RecipeImporter.servings(from: 6) == 6)
        #expect(RecipeImporter.servings(from: "serves a crowd") == 1)
    }

    @Test("Nutrition strings become numbers")
    func nutritionParsing() {
        #expect(RecipeImporter.number(from: "23 g") == 23)
        #expect(RecipeImporter.number(from: "450 calories") == 450)
        #expect(RecipeImporter.number(from: "12.5g") == 12.5)
    }

    @Test("Ingredient lines split into quantity, unit and name")
    func ingredientParsing() {
        let line = RecipeImporter.parseIngredient("2 tbsp olive oil")
        #expect(line.quantity == 2)
        #expect(line.unit == "tbsp")
        #expect(line.name == "olive oil")
        #expect(line.aisle == .pantry)

        let fraction = RecipeImporter.parseIngredient("1/2 cup rice")
        #expect(fraction.quantity == 0.5)
        #expect(fraction.unit == "cup")
    }

    @Test("A full JSON-LD page parses into a draft")
    func parsesStructuredData() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@context":"https://schema.org","@graph":[
          {"@type":"WebPage","name":"ignore me"},
          {"@type":"Recipe","name":"Test Soup","description":"A soup.",
           "recipeYield":"4 servings","prepTime":"PT10M","cookTime":"PT25M",
           "recipeIngredient":["2 tbsp olive oil","1 onion","500 g carrots"],
           "recipeInstructions":[{"@type":"HowToStep","text":"Chop."},
                                 {"@type":"HowToStep","text":"Simmer."}],
           "nutrition":{"@type":"NutritionInformation","calories":"320 calories","proteinContent":"12 g"}}
        ]}
        </script>
        </head><body></body></html>
        """

        let draft = try RecipeImporter.parse(html: html, sourceURL: "https://example.com/soup")

        #expect(draft.title == "Test Soup")
        #expect(draft.servings == 4)
        #expect(draft.prepMinutes == 10)
        #expect(draft.cookMinutes == 25)
        #expect(draft.ingredientTexts.count == 3)
        #expect(draft.steps == ["Chop.", "Simmer."])
        #expect(draft.calories == 320)
        #expect(draft.proteinG == 12)
    }

    @Test("A page with no structured data fails cleanly")
    func noStructuredDataThrows() {
        #expect(throws: RecipeImporter.ImportError.self) {
            try RecipeImporter.parse(html: "<html><body>just words</body></html>", sourceURL: "https://example.com")
        }
    }
}

// MARK: - Meal planning

@Suite("Meal planning")
struct MealPlannerTests {

    @Test("The seed library covers every meal slot")
    func libraryIsComplete() {
        let recipes = RecipeLibrary.seedRecipes()
        for slot in MealSlot.allCases {
            #expect(recipes.contains { $0.mealSlot == slot })
        }
    }

    @Test("Default filters respect a limited standing tolerance")
    func filterRespectsStandingLimit() {
        let profile = makeProfile(mobility: .moderateLimitation, standingMinutes: 6)
        let filter = MealPlanner.defaultFilter(for: profile, tier: .medium)
        let results = MealPlanner.apply(filter, to: RecipeLibrary.seedRecipes())

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.standingMinutes <= 6 })
    }

    @Test("Vegan filtering excludes anything not tagged vegan")
    func veganFiltering() {
        var filter = MealPlanner.Filter.none
        filter.dietary = [.vegan]
        let results = MealPlanner.apply(filter, to: RecipeLibrary.seedRecipes())

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.dietaryTags.contains(.vegan) })
    }

    @Test("A generated week covers seven days of every main slot")
    func weekGenerationIsComplete() {
        let profile = makeProfile(age: 68, mobility: .mildLimitation)
        let start = Calendar.current.startOfDay(for: Date())
        let meals = MealPlanner.generateWeek(
            startingOn: start,
            recipes: RecipeLibrary.seedRecipes(),
            profile: profile,
            tier: .medium
        )

        for slot in [MealSlot.breakfast, .lunch, .dinner] {
            let days = Set(meals.filter { $0.slot == slot }.map { Calendar.current.startOfDay(for: $0.date) })
            #expect(days.count == 7)
        }
    }

    @Test("A prep session inserts sit-down breaks for limited standing")
    func prepSessionInsertsBreaks() {
        let profile = makeProfile(mobility: .moderateLimitation, standingMinutes: 10)
        let recipes = RecipeLibrary.seedRecipes().filter(\.batchFriendly)
        let entries = recipes.prefix(4).map {
            MealPlanEntry(date: Date(), slot: $0.mealSlot, recipe: $0, servings: 1)
        }

        let steps = MealPlanner.prepSession(for: Array(entries), recipes: recipes, profile: profile)

        #expect(!steps.isEmpty)
        #expect(steps.contains { $0.title.contains("Sit down") })
    }

    @Test("Shopping list merges duplicate ingredients across recipes")
    func shoppingListMerges() {
        let recipes = RecipeLibrary.seedRecipes()
        guard let first = recipes.first(where: { $0.ingredients.contains { $0.name == "eggs" } }) else { return }

        let entries = [
            MealPlanEntry(date: Date(), slot: first.mealSlot, recipe: first, servings: first.servings),
            MealPlanEntry(date: Date(), slot: first.mealSlot, recipe: first, servings: first.servings)
        ]
        let items = MealPlanner.buildShoppingList(from: entries, recipes: recipes, weekStart: Date())

        let eggLines = items.filter { $0.name == "eggs" }
        #expect(eggLines.count == 1)
        #expect((eggLines.first?.quantity ?? 0) > 0)
    }

    @Test("The shopping list comes out in supermarket walking order")
    func shoppingListIsAisleSorted() {
        let recipes = RecipeLibrary.seedRecipes()
        let entries = recipes.prefix(5).map {
            MealPlanEntry(date: Date(), slot: $0.mealSlot, recipe: $0, servings: 1)
        }
        let items = MealPlanner.buildShoppingList(from: Array(entries), recipes: recipes, weekStart: Date())

        let orders = items.map(\.aisle.walkOrder)
        #expect(orders == orders.sorted())
    }
}
