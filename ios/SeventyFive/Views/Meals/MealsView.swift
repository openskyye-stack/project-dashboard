import SwiftUI
import SwiftData

struct MealsView: View {
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    let profile: UserProfile
    let run: ChallengeRun

    @State private var section: MealSection = .plan
    @State private var weekStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var showImport = false

    enum MealSection: String, CaseIterable, Identifiable {
        case plan = "Plan"
        case recipes = "Recipes"
        case shopping = "Shopping"
        case prep = "Prep"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(MealSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                switch section {
                case .plan:
                    WeekPlanView(profile: profile, run: run, weekStart: $weekStart, recipes: recipes)
                case .recipes:
                    RecipeListView(profile: profile, run: run, recipes: recipes)
                case .shopping:
                    ShoppingListView(weekStart: weekStart)
                case .prep:
                    PrepSessionView(profile: profile, weekStart: weekStart, recipes: recipes)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImport = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }
                    .accessibilityLabel("Import a recipe from the web")
                }
            }
            .sheet(isPresented: $showImport) {
                RecipeImportSheet()
            }
        }
    }
}

// MARK: - Week plan

struct WeekPlanView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let run: ChallengeRun
    @Binding var weekStart: Date
    let recipes: [Recipe]

    @State private var entries: [MealPlanEntry] = []

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                weekSelector

                if entries.isEmpty {
                    EmptyStateView(
                        title: "No plan for this week",
                        message: "Build one from the recipes that fit your tier, your diet and how long you can stand at a hob.",
                        systemImage: "calendar.badge.plus",
                        actionTitle: "Build my week",
                        action: generate
                    )
                    .card()
                } else {
                    ForEach(days, id: \.self) { day in
                        DayPlanCard(
                            date: day,
                            entries: entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) },
                            recipes: recipes
                        )
                    }

                    Button(action: generate) {
                        Label("Rebuild this week", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(16)
        }
        .task { reload() }
        .onChange(of: weekStart) { _, _ in reload() }
    }

    private var weekSelector: some View {
        HStack {
            Button {
                shiftWeek(-7)
            } label: {
                Image(systemName: "chevron.left").comfortableTapTarget()
            }
            Spacer()
            VStack(spacing: 2) {
                Text(weekStart.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Text("week of")
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
            }
            Spacer()
            Button {
                shiftWeek(7)
            } label: {
                Image(systemName: "chevron.right").comfortableTapTarget()
            }
        }
        .card()
    }

    private func shiftWeek(_ days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: weekStart) {
            weekStart = Calendar.current.startOfDay(for: next)
        }
    }

    private func reload() {
        entries = store.mealEntries(from: weekStart)
    }

    private func generate() {
        store.generateWeekPlan(from: weekStart, profile: profile, tier: run.tier)
        store.rebuildShoppingList(weekStart: weekStart)
        reload()
        Haptics.complete()
    }
}

struct DayPlanCard: View {
    let date: Date
    let entries: [MealPlanEntry]
    let recipes: [Recipe]

    private var byID: [UUID: Recipe] {
        Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.headline)
                Spacer()
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
                if Calendar.current.isDateInToday(date) {
                    TagPill(text: "today", tint: .accentColor)
                }
            }

            if entries.isEmpty {
                Text("Nothing planned.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
            } else {
                ForEach(MealSlot.allCases) { slot in
                    let slotEntries = entries.filter { $0.slot == slot }
                    if !slotEntries.isEmpty {
                        ForEach(slotEntries) { entry in
                            NavigationLink {
                                if let recipe = byID[entry.recipeID] {
                                    RecipeDetailView(recipe: recipe)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: slot.symbol)
                                        .foregroundStyle(Theme.subtle)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.recipeTitle)
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(Theme.ink)
                                            .multilineTextAlignment(.leading)
                                        Text(slot.displayName)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.subtle)
                                    }
                                    Spacer(minLength: 0)
                                    if let recipe = byID[entry.recipeID] {
                                        Text("\(Int(recipe.proteinPerServing))g")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Theme.success)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Theme.subtle)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .card()
    }
}
