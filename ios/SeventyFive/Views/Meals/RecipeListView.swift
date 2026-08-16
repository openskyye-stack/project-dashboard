import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let run: ChallengeRun
    let recipes: [Recipe]

    @State private var filter = MealPlanner.Filter.none
    @State private var didApplyDefaults = false
    @State private var showAllRecipes = false

    private var filtered: [Recipe] {
        showAllRecipes
            ? MealPlanner.apply(searchOnly, to: recipes)
            : MealPlanner.apply(filter, to: recipes)
    }

    private var searchOnly: MealPlanner.Filter {
        var f = MealPlanner.Filter.none
        f.searchText = filter.searchText
        f.slot = filter.slot
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                filterBar

                if filtered.isEmpty {
                    EmptyStateView(
                        title: "Nothing matches",
                        message: "Loosen a filter, or import a recipe from a site you already use.",
                        systemImage: "magnifyingglass"
                    )
                    .card()
                } else {
                    ForEach(filtered) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeRow(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .searchable(text: Binding(
            get: { filter.searchText },
            set: { filter.searchText = $0 }
        ), prompt: "Search recipes")
        .onAppear {
            guard !didApplyDefaults else { return }
            var defaults = MealPlanner.defaultFilter(for: profile, tier: run.tier)
            defaults.searchText = filter.searchText
            filter = defaults
            didApplyDefaults = true
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isOn: filter.slot == nil) { filter.slot = nil }
                    ForEach(MealSlot.allCases) { slot in
                        FilterChip(title: slot.displayName, systemImage: slot.symbol, isOn: filter.slot == slot) {
                            filter.slot = filter.slot == slot ? nil : slot
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Batch cook", systemImage: "shippingbox.fill", isOn: filter.batchOnly) {
                        filter.batchOnly.toggle()
                    }
                    FilterChip(title: "Seated prep", systemImage: "chair.fill", isOn: filter.requiresSeatedPrep) {
                        filter.requiresSeatedPrep.toggle()
                    }
                    FilterChip(title: "One-handed", systemImage: "hand.raised.fill", isOn: filter.requiresOneHanded) {
                        filter.requiresOneHanded.toggle()
                    }
                    FilterChip(title: "Easy to chew", systemImage: "mouth.fill", isOn: filter.requiresSoftTexture) {
                        filter.requiresSoftTexture.toggle()
                    }
                    FilterChip(title: "Under 20 min", systemImage: "timer", isOn: filter.maxTotalMinutes != nil) {
                        filter.maxTotalMinutes = filter.maxTotalMinutes == nil ? 20 : nil
                    }
                }
            }

            Toggle(isOn: $showAllRecipes) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Show everything").font(.footnote.weight(.medium))
                    Text("Ignores your tier, diet and standing limits.")
                        .font(.caption2)
                        .foregroundStyle(Theme.subtle)
                }
            }
            .font(.footnote)
        }
        .card()
    }
}

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(recipe.summary)
                        .font(.footnote)
                        .foregroundStyle(Theme.subtle)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(recipe.proteinPerServing))g")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.success)
                    Text("protein").font(.caption2).foregroundStyle(Theme.subtle)
                }
            }

            HStack(spacing: 6) {
                TagPill(text: "\(recipe.totalMinutes) min", systemImage: "clock")
                TagPill(
                    text: recipe.standingMinutes == 0 ? "no standing" : "\(recipe.standingMinutes) min standing",
                    systemImage: "figure.stand",
                    tint: recipe.standingMinutes <= 10 ? Theme.success : Theme.warning
                )
                if recipe.batchFriendly {
                    TagPill(text: "batch", systemImage: "shippingbox.fill", tint: .blue)
                }
                if recipe.softTexture {
                    TagPill(text: "soft", tint: .teal)
                }
            }
        }
        .card()
    }
}

struct RecipeDetailView: View {
    @Environment(ChallengeStore.self) private var store
    let recipe: Recipe

    @State private var showAddToPlan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                nutrition
                accessibilityNotes
                ingredients
                method

                if let source = recipe.sourceURL, let url = URL(string: source) {
                    Link(destination: url) {
                        Label("Original recipe", systemImage: "safari")
                    }
                    .font(.footnote)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    recipe.isFavorite.toggle()
                    store.save()
                    Haptics.tap()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(recipe.isFavorite ? "Remove from favourites" : "Add to favourites")
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showAddToPlan = true
                } label: {
                    Label("Add to plan", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showAddToPlan) {
            AddToPlanSheet(recipe: recipe)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.summary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                MetricColumn(value: "\(recipe.prepMinutes)", unit: "min prep")
                MetricColumn(value: "\(recipe.cookMinutes)", unit: "min cook")
                MetricColumn(value: "\(recipe.servings)", unit: "servings")
            }
        }
        .card()
    }

    private var nutrition: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Per serving", systemImage: "chart.pie.fill")
            HStack(spacing: 18) {
                MetricColumn(value: "\(recipe.caloriesPerServing)", unit: "kcal")
                MetricColumn(value: "\(Int(recipe.proteinPerServing))g", unit: "protein", tint: Theme.success)
                MetricColumn(value: "\(Int(recipe.carbsG / Double(max(1, recipe.servings))))g", unit: "carbs")
                MetricColumn(value: "\(Int(recipe.fatG / Double(max(1, recipe.servings))))g", unit: "fat")
            }
            if recipe.calories == 0 {
                Text("This recipe came from the web without nutrition data.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
            }
        }
        .card()
    }

    private var accessibilityNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Effort", systemImage: "figure.stand")
            HStack(spacing: 8) {
                TagPill(
                    text: recipe.standingMinutes == 0 ? "Nothing standing" : "\(recipe.standingMinutes) min standing",
                    systemImage: "figure.stand",
                    tint: recipe.standingMinutes <= 10 ? Theme.success : Theme.warning
                )
                if recipe.seatedPrepFriendly { TagPill(text: "Seated prep", systemImage: "chair.fill", tint: .teal) }
                if recipe.oneHandedFriendly { TagPill(text: "One-handed", tint: .teal) }
            }
            HStack(spacing: 8) {
                if recipe.batchFriendly { TagPill(text: "Batch friendly", systemImage: "shippingbox.fill", tint: .blue) }
                if recipe.lowKnifeSkill { TagPill(text: "Little chopping", tint: .blue) }
                if recipe.softTexture { TagPill(text: "Easy to chew", tint: .teal) }
            }
        }
        .card()
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Ingredients", subtitle: "Makes \(recipe.servings)", systemImage: "list.bullet")
            ForEach(recipe.ingredients) { line in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Theme.subtle)
                        .padding(.top, 7)
                    Text(line.display)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    if line.isOptional {
                        TagPill(text: "optional", tint: Theme.subtle)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .card()
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Method", systemImage: "text.line.first.and.arrowtriangle.forward")
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.callout.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                    Text(step)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .card()
    }
}

struct MetricColumn: View {
    let value: String
    let unit: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(Theme.subtle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(unit)")
    }
}

struct AddToPlanSheet: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe

    @State private var date = Date()
    @State private var slot: MealSlot = .dinner
    @State private var servings: Double = 1

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $date, displayedComponents: .date)

                Picker("Meal", selection: $slot) {
                    ForEach(MealSlot.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Servings").font(.footnote).foregroundStyle(Theme.subtle)
                    LabelledStepper(value: $servings, range: 1...8, step: 1, format: { "\(Int($0))" })
                }
            }
            .navigationTitle("Add to plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        store.planMeal(recipe: recipe, on: date, slot: slot, servings: Int(servings))
                        Haptics.complete()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { slot = recipe.mealSlot }
        }
    }
}
