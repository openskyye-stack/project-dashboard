import SwiftUI
import SwiftData

/// Aisle-ordered shopping list built from the week's plan.
struct ShoppingListView: View {
    @Environment(ChallengeStore.self) private var store
    @Query private var allItems: [ShoppingItem]

    let weekStart: Date

    @State private var newItemName = ""

    private var items: [ShoppingItem] {
        allItems
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }
            .sorted { lhs, rhs in
                if lhs.isChecked != rhs.isChecked { return !lhs.isChecked }
                if lhs.aisle.walkOrder != rhs.aisle.walkOrder { return lhs.aisle.walkOrder < rhs.aisle.walkOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var grouped: [(GroceryAisle, [ShoppingItem])] {
        Dictionary(grouping: items.filter { !$0.isChecked }, by: \.aisle)
            .sorted { $0.key.walkOrder < $1.key.walkOrder }
            .map { ($0.key, $0.value) }
    }

    private var checked: [ShoppingItem] { items.filter(\.isChecked) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if items.isEmpty {
                    EmptyStateView(
                        title: "No shopping list yet",
                        message: "Plan a week first, then the list builds itself — merged, scaled and sorted the way you walk a shop.",
                        systemImage: "cart",
                        actionTitle: "Build from this week's plan",
                        action: { store.rebuildShoppingList(weekStart: weekStart) }
                    )
                    .card()
                } else {
                    progressCard

                    ForEach(grouped, id: \.0) { aisle, aisleItems in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: aisle.displayName)
                            ForEach(aisleItems) { item in
                                ShoppingRow(item: item) { toggle(item) }
                            }
                        }
                        .card()
                    }

                    if !checked.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "In the trolley", subtitle: "\(checked.count) items")
                            ForEach(checked) { item in
                                ShoppingRow(item: item) { toggle(item) }
                            }
                        }
                        .card()
                    }
                }

                addItemRow
            }
            .padding(16)
        }
    }

    private var progressCard: some View {
        let done = checked.count
        let total = items.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(done) of \(total)").font(.headline)
                Spacer()
                Button("Rebuild") { store.rebuildShoppingList(weekStart: weekStart) }
                    .font(.footnote.weight(.medium))
            }
            ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                .tint(Theme.success)
        }
        .card()
    }

    private var addItemRow: some View {
        HStack(spacing: 10) {
            TextField("Add something else", text: $newItemName)
                .textFieldStyle(.roundedBorder)
            Button {
                let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let item = ShoppingItem(
                    name: trimmed,
                    quantity: 1,
                    unit: "",
                    aisle: RecipeImporter.guessAisle(trimmed),
                    sourceRecipes: [],
                    weekStart: weekStart,
                    isManuallyAdded: true
                )
                store.context.insert(item)
                store.save()
                newItemName = ""
                Haptics.tap()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .comfortableTapTarget()
            }
            .accessibilityLabel("Add item")
        }
        .card()
    }

    private func toggle(_ item: ShoppingItem) {
        item.isChecked.toggle()
        store.save()
        Haptics.tap()
    }
}

struct ShoppingRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Theme.success : Theme.subtle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.display)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .strikethrough(item.isChecked, color: Theme.subtle)
                        .multilineTextAlignment(.leading)
                    if !item.sourceRecipes.isEmpty {
                        Text(item.sourceRecipes.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(Theme.subtle)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Theme.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(item.isChecked ? [.isSelected, .isButton] : .isButton)
    }
}

/// The batch-prep session: an ordered plan with standing time made explicit and
/// sit-down breaks inserted where they're needed.
struct PrepSessionView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let weekStart: Date
    let recipes: [Recipe]

    @State private var steps: [MealPlanner.PrepStep] = []
    @State private var completed: Set<String> = []

    private var totalMinutes: Int { steps.reduce(0) { $0 + $1.minutes } }
    private var standingMinutes: Int { steps.filter { !$0.isSeated }.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if steps.isEmpty {
                    EmptyStateView(
                        title: "No prep session",
                        message: "Plan a week with some batch-friendly recipes and this becomes an ordered session — longest cook first, all the chopping in one seated block.",
                        systemImage: "timer"
                    )
                    .card()
                } else {
                    summaryCard

                    ForEach(steps) { step in
                        PrepStepRow(
                            step: step,
                            isDone: completed.contains(step.id)
                        ) {
                            if completed.contains(step.id) {
                                completed.remove(step.id)
                            } else {
                                completed.insert(step.id)
                                Haptics.tap()
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .task { reload() }
        .onChange(of: weekStart) { _, _ in reload() }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "This week's prep",
                subtitle: "Do it once and the week stops asking you questions.",
                systemImage: "shippingbox.fill"
            )
            HStack(spacing: 20) {
                MetricColumn(value: "\(totalMinutes)", unit: "min total")
                MetricColumn(
                    value: "\(standingMinutes)",
                    unit: "min standing",
                    tint: standingMinutes > profile.continuousStandingMinutes * 2 ? Theme.warning : Theme.success
                )
                MetricColumn(value: "\(completed.count)/\(steps.count)", unit: "done")
            }
            ProgressView(value: steps.isEmpty ? 0 : Double(completed.count) / Double(steps.count))
                .tint(Theme.success)
        }
        .card()
    }

    private func reload() {
        let entries = store.mealEntries(from: weekStart)
        steps = MealPlanner.prepSession(for: entries, recipes: recipes, profile: profile)
        completed = []
    }
}

struct PrepStepRow: View {
    let step: MealPlanner.PrepStep
    let isDone: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isDone ? Theme.success : Color(.tertiarySystemBackground))
                        .frame(width: 40, height: 40)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Text("\(step.order)")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .strikethrough(isDone, color: Theme.subtle)
                        .multilineTextAlignment(.leading)
                    Text(step.detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.subtle)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        TagPill(text: "\(step.minutes) min", systemImage: "clock")
                        TagPill(
                            text: step.isSeated ? "seated" : "standing",
                            systemImage: step.isSeated ? "chair.fill" : "figure.stand",
                            tint: step.isSeated ? Theme.success : Theme.warning
                        )
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .card(tint: isDone ? Theme.success : .clear)
    }
}

/// Pulls a recipe from any site that publishes schema.org structured data.
struct RecipeImportSheet: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var slot: MealSlot = .dinner
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var importedTitle: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Paste a recipe link")
                        .font(.title2.bold())

                    Text("Most recipe sites publish machine-readable data behind the page — the same data Google reads for its recipe cards. We read that, so nothing breaks when the site changes its layout.")
                        .font(.footnote)
                        .foregroundStyle(Theme.subtle)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("https://…", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let errorMessage {
                        SafetyNote(text: errorMessage, isCritical: true)
                    }

                    if let importedTitle {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Imported \(importedTitle)", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                            Text("Check the ingredients — quantities are parsed from free text and occasionally need a nudge. Tag it with a tier in the recipe list so the planner can use it.")
                                .font(.caption)
                                .foregroundStyle(Theme.subtle)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .card(tint: Theme.success)
                    }

                    Button {
                        Task { await performImport() }
                    } label: {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Import").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading || urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Import recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func performImport() async {
        isLoading = true
        errorMessage = nil
        importedTitle = nil
        do {
            let recipe = try await store.importRecipe(from: urlString, slot: slot)
            importedTitle = recipe.title
            urlString = ""
            Haptics.complete()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.warn()
        }
        isLoading = false
    }
}
