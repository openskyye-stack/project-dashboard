import SwiftUI
import SwiftData

/// The interview.
///
/// This is the most important screen in the app. Every question here exists
/// because the answer changes the plan — nothing is asked for analytics, and
/// nothing is asked twice. The order matters too: identity and body first,
/// limits second, preferences third, motivation last, because people give
/// honest answers about pain before they've been told what the app wants to hear.
@Observable
final class OnboardingDraft {
    var name: String = ""
    var birthYear: Int = Calendar.current.component(.year, from: Date()) - 45
    var weightKg: Double = 75
    var heightCm: Double = 170
    var usesMetric: Bool = !UnitPreference.usesImperial

    var mobility: MobilityLevel = .unrestricted
    var jointPain: PainLevel = .none
    var balanceConfidence: Int = 4
    var hasFallenInLastYear: Bool = false
    var continuousStandingMinutes: Int = 30

    var considerations: Set<HealthConsideration> = []
    var clinicianCleared: Bool = false

    var equipment: Set<EquipmentItem> = []
    var outdoorAccess: OutdoorAccess = .easy

    var availableMinutesPerDay: Int = 90
    var preferredStartHour: Int = 7
    var preferredWindDownHour: Int = 21

    var dietary: Set<DietaryPreference> = []
    var readingFormat: ReadingFormat = .print

    var whyStatement: String = ""
    var rewardAnswers: [String] = ["", "", ""]

    var wantsLargeText: Bool = false
    var wantsReducedMotion: Bool = false

    func buildProfile() -> UserProfile {
        let profile = UserProfile()
        profile.name = name
        profile.birthYear = birthYear
        profile.weightKg = weightKg
        profile.heightCm = heightCm
        profile.mobility = mobility
        profile.jointPain = jointPain
        profile.balanceConfidence = balanceConfidence
        profile.hasFallenInLastYear = hasFallenInLastYear
        profile.continuousStandingMinutes = continuousStandingMinutes
        profile.considerations = Array(considerations)
        profile.clinicianCleared = clinicianCleared
        profile.equipment = Array(equipment)
        profile.outdoorAccess = outdoorAccess
        profile.availableMinutesPerDay = availableMinutesPerDay
        profile.preferredStartHour = preferredStartHour
        profile.preferredWindDownHour = preferredWindDownHour
        profile.dietary = Array(dietary)
        profile.readingFormat = readingFormat
        profile.whyStatement = whyStatement
        profile.wantsLargeText = wantsLargeText
        profile.wantsReducedMotion = wantsReducedMotion
        return profile
    }

    /// A throwaway profile so the recommendation screen can preview the plan
    /// before anything is written to the database.
    func previewProfile() -> UserProfile { buildProfile() }
}

struct OnboardingFlow: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.modelContext) private var context

    @State private var draft = OnboardingDraft()
    @State private var step: Int = 0

    private let stepCount = 11

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(stepCount))
                    .tint(.accentColor)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityLabel("Step \(step + 1) of \(stepCount)")

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        content
                    }
                    .padding(20)
                }

                footer
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { withAnimation { step -= 1 } }
                    }
                }
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Before we start"
        case 1: return "About you"
        case 2: return "Your body"
        case 3: return "Moving around"
        case 4: return "Pain & steadiness"
        case 5: return "Health"
        case 6: return "What you've got"
        case 7: return "Your day"
        case 8: return "Food & reading"
        case 9: return "Why"
        default: return "Your plan"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: WelcomeStep()
        case 1: IdentityStep(draft: draft)
        case 2: BodyStep(draft: draft)
        case 3: MobilityStep(draft: draft)
        case 4: PainBalanceStep(draft: draft)
        case 5: HealthStep(draft: draft)
        case 6: EquipmentStep(draft: draft)
        case 7: ScheduleStep(draft: draft)
        case 8: PreferencesStep(draft: draft)
        case 9: MotivationStep(draft: draft)
        default: RecommendationStep(draft: draft, onStart: commit)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if step < stepCount - 1 {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    Text(step == 0 ? "Let's go" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canContinue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(.bar)
    }

    private var canContinue: Bool {
        switch step {
        case 1: return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func commit(tier: ChallengeTier) {
        let profile = draft.buildProfile()
        context.insert(profile)

        // Turn the reward answers into real rewards, priced by how big they are.
        let costs = [40, 150, 400]
        for (index, answer) in draft.rewardAnswers.enumerated() {
            let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let reward = Reward(
                title: trimmed,
                detail: RewardCatalog.promptQuestions[min(index, RewardCatalog.promptQuestions.count - 1)],
                cost: costs[min(index, costs.count - 1)],
                category: index == 0 ? .treat : (index == 1 ? .experience : .milestone),
                isCustom: true
            )
            context.insert(reward)
        }

        store.save()
        store.startRun(tier: tier, profile: profile)

        Task { _ = await NotificationManager.shared.requestAuthorization() }
    }
}

// MARK: - Step 0

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Seventy-five days.")
                .font(.largeTitle.bold())

            Text("The original 75 Hard hands everyone the same rules: two 45-minute workouts, a gallon of water, no exceptions, restart if you slip. It works for some people and injures others.")
                .font(.body)

            Text("This app asks first. Your age, your joints, how long you can stay on your feet, what a bad morning actually feels like — then it builds the version of the challenge you can finish.")
                .font(.body)

            SafetyNote(
                text: "This is a habit app, not medical advice. If you have a heart condition, are on medication that affects fluid balance, or have had surgery recently, talk to your doctor before you start — and bring the plan this app generates with you.",
                isCritical: true
            )

            VStack(alignment: .leading, spacing: 12) {
                Label("Everything stays on this phone. No account, no server.", systemImage: "lock.fill")
                Label("Ten questions. Under three minutes.", systemImage: "clock.fill")
                Label("You can change any answer later.", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.callout)
            .foregroundStyle(Theme.subtle)
        }
    }
}

// MARK: - Step 1

private struct IdentityStep: View {
    @Bindable var draft: OnboardingDraft

    private var years: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 100)...(current - 16)).reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            QuestionBlock(
                question: "What should we call you?",
                why: "It shows up on your morning check-in. Nothing else."
            ) {
                TextField("Your name", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .textContentType(.givenName)
            }

            QuestionBlock(
                question: "What year were you born?",
                why: "Age changes three things: how long each session should be, how much water is sensible, and whether balance training gets added. It is never used to tell you what you can't do."
            ) {
                Picker("Birth year", selection: $draft.birthYear) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 130)
            }
        }
    }
}

// MARK: - Step 2

private struct BodyStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Toggle("Use metric (kg / cm)", isOn: $draft.usesMetric)
                .font(.callout)

            QuestionBlock(
                question: "Roughly what do you weigh?",
                why: "Your water target is calculated per kilogram of body weight. A fixed gallon is far too much for some people and not enough for others."
            ) {
                if draft.usesMetric {
                    LabelledStepper(
                        value: $draft.weightKg,
                        range: 35...200,
                        step: 1,
                        format: { "\(Int($0)) kg" }
                    )
                } else {
                    LabelledStepper(
                        value: Binding(
                            get: { draft.weightKg * 2.20462 },
                            set: { draft.weightKg = $0 / 2.20462 }
                        ),
                        range: 77...440,
                        step: 2,
                        format: { "\(Int($0)) lb" }
                    )
                }
            }

            QuestionBlock(
                question: "And your height?",
                why: "Used only to show your progress in context. It doesn't change any rule."
            ) {
                if draft.usesMetric {
                    LabelledStepper(
                        value: $draft.heightCm,
                        range: 120...220,
                        step: 1,
                        format: { "\(Int($0)) cm" }
                    )
                } else {
                    LabelledStepper(
                        value: Binding(
                            get: { draft.heightCm / 2.54 },
                            set: { draft.heightCm = $0 * 2.54 }
                        ),
                        range: 47...87,
                        step: 1,
                        format: { value in
                            let inches = Int(value)
                            return "\(inches / 12) ft \(inches % 12) in"
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Step 3

private struct MobilityStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        QuestionBlock(
            question: "How would you describe getting around?",
            why: "This decides the shape of every workout. Whatever you pick, you still do a workout every day — it just becomes the right kind."
        ) {
            VStack(spacing: 10) {
                ForEach(MobilityLevel.allCases) { level in
                    SelectableRow(
                        title: level.displayName,
                        subtitle: level.detail,
                        isSelected: draft.mobility == level
                    ) {
                        draft.mobility = level
                        // A seated user's realistic standing time is zero.
                        if level == .seated { draft.continuousStandingMinutes = 0 }
                    }
                }
            }
        }
    }
}

// MARK: - Step 4

private struct PainBalanceStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            QuestionBlock(
                question: "On an average day, how much joint pain do you have?",
                why: "Pain shortens sessions and rules out impact. Be honest here — the app can't adapt around something you hide from it."
            ) {
                VStack(spacing: 10) {
                    ForEach(PainLevel.allCases) { level in
                        SelectableRow(
                            title: level.displayName,
                            subtitle: nil,
                            isSelected: draft.jointPain == level
                        ) { draft.jointPain = level }
                    }
                }
            }

            QuestionBlock(
                question: "How steady are you on your feet?",
                why: "Falls end more challenges than motivation does. If you're unsteady, balance training gets added and the outdoor rule moves to level ground."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(draft.balanceConfidence) },
                            set: { draft.balanceConfidence = Int($0.rounded()) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    HStack {
                        Text("Unsteady").font(.caption).foregroundStyle(Theme.subtle)
                        Spacer()
                        Text(balanceLabel).font(.callout.weight(.medium))
                        Spacer()
                        Text("Rock solid").font(.caption).foregroundStyle(Theme.subtle)
                    }
                }
            }

            Toggle(isOn: $draft.hasFallenInLastYear) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("I've fallen in the last year")
                    Text("Including trips and near-misses you caught yourself from.")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
            }

            QuestionBlock(
                question: "How long can you keep going before you need to sit down?",
                why: "If this is under your session length, the app splits the workout into chunks. Three ten-minute walks count exactly the same as one thirty-minute walk."
            ) {
                LabelledStepper(
                    value: Binding(
                        get: { Double(draft.continuousStandingMinutes) },
                        set: { draft.continuousStandingMinutes = Int($0) }
                    ),
                    range: 0...90,
                    step: 5,
                    format: { $0 <= 0 ? "I exercise seated" : "\(Int($0)) minutes" }
                )
            }
        }
    }

    private var balanceLabel: String {
        switch draft.balanceConfidence {
        case 1: return "Very unsteady"
        case 2: return "Unsteady"
        case 3: return "Reasonable"
        case 4: return "Good"
        default: return "Rock solid"
        }
    }
}

// MARK: - Step 5

private struct HealthStep: View {
    @Bindable var draft: OnboardingDraft

    private var options: [HealthConsideration] {
        HealthConsideration.allCases.filter { $0 != .none }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            QuestionBlock(
                question: "Does any of this apply to you?",
                why: "These change real numbers: intensity caps, whether impact is allowed, and — for kidney or heart conditions — your water target, which can be dangerous if it's set by a slogan instead of a clinician."
            ) {
                VStack(spacing: 8) {
                    ForEach(options) { option in
                        MultiSelectRow(
                            title: option.displayName,
                            subtitle: option.safetyNote,
                            isSelected: draft.considerations.contains(option)
                        ) {
                            if draft.considerations.contains(option) {
                                draft.considerations.remove(option)
                            } else {
                                draft.considerations.insert(option)
                            }
                        }
                    }
                }
            }

            if !draft.considerations.isEmpty {
                SafetyNote(
                    text: "Take the plan the app builds to your next appointment. It's a page long and it's specific — that's a much better conversation than 'I'm thinking of doing a fitness challenge'.",
                    isCritical: true
                )

                Toggle("A clinician has cleared me for exercise", isOn: $draft.clinicianCleared)
            }
        }
    }
}

// MARK: - Step 6

private struct EquipmentStep: View {
    @Bindable var draft: OnboardingDraft

    private var options: [EquipmentItem] {
        EquipmentItem.allCases.filter { $0 != .none }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            QuestionBlock(
                question: "What have you got to work with?",
                why: "Only exercises you can actually do get suggested. A sturdy chair is assumed — it's the most useful piece of equipment in the list."
            ) {
                VStack(spacing: 8) {
                    ForEach(options) { item in
                        MultiSelectRow(
                            title: item.displayName,
                            subtitle: nil,
                            symbol: item.symbol,
                            isSelected: draft.equipment.contains(item)
                        ) {
                            if draft.equipment.contains(item) {
                                draft.equipment.remove(item)
                            } else {
                                draft.equipment.insert(item)
                            }
                        }
                    }
                }
            }

            QuestionBlock(
                question: "Can you get outside every day?",
                why: "75 Hard demands an outdoor workout in any weather. If ice or transport makes that unsafe or impossible for you, the rule gets rewritten rather than quietly broken."
            ) {
                VStack(spacing: 10) {
                    ForEach(OutdoorAccess.allCases) { access in
                        SelectableRow(
                            title: access.displayName,
                            subtitle: nil,
                            isSelected: draft.outdoorAccess == access
                        ) { draft.outdoorAccess = access }
                    }
                }
            }
        }
    }
}

// MARK: - Step 7

private struct ScheduleStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            QuestionBlock(
                question: "Realistically, how many minutes a day can you give this?",
                why: "The plan is sized to this number. A plan you can finish beats a plan you admire."
            ) {
                LabelledStepper(
                    value: Binding(
                        get: { Double(draft.availableMinutesPerDay) },
                        set: { draft.availableMinutesPerDay = Int($0) }
                    ),
                    range: 30...180,
                    step: 10,
                    format: { "\(Int($0)) minutes" }
                )
            }

            QuestionBlock(
                question: "When does your day start and wind down?",
                why: "Water reminders are spaced between these two, and stop two hours before wind-down so you're not up at 3am."
            ) {
                VStack(spacing: 16) {
                    HourPicker(title: "Up at", hour: $draft.preferredStartHour)
                    HourPicker(title: "Winding down at", hour: $draft.preferredWindDownHour)
                }
            }
        }
    }
}

// MARK: - Step 8

private struct PreferencesStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            QuestionBlock(
                question: "Anything we should know about food?",
                why: "Recipes are filtered to what you'll actually eat. 'Easy to chew' is in the list because dental work and dry mouth are common and rarely asked about."
            ) {
                VStack(spacing: 8) {
                    ForEach(DietaryPreference.allCases.filter { $0 != .none }) { preference in
                        MultiSelectRow(
                            title: preference.displayName,
                            subtitle: nil,
                            isSelected: draft.dietary.contains(preference)
                        ) {
                            if draft.dietary.contains(preference) {
                                draft.dietary.remove(preference)
                            } else {
                                draft.dietary.insert(preference)
                            }
                        }
                    }
                }
            }

            QuestionBlock(
                question: "How do you prefer to read?",
                why: "Ten pages becomes fifteen minutes if you're listening. Same habit, honest conversion — audiobooks aren't cheating."
            ) {
                VStack(spacing: 10) {
                    ForEach(ReadingFormat.allCases) { format in
                        SelectableRow(
                            title: format.displayName,
                            subtitle: nil,
                            isSelected: draft.readingFormat == format
                        ) { draft.readingFormat = format }
                    }
                }
            }

            QuestionBlock(
                question: "Anything to make the app easier to use?",
                why: nil
            ) {
                VStack(spacing: 10) {
                    Toggle("Larger text everywhere", isOn: $draft.wantsLargeText)
                    Toggle("Reduce animation", isOn: $draft.wantsReducedMotion)
                }
            }
        }
    }
}

// MARK: - Step 9

private struct MotivationStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            QuestionBlock(
                question: "Why are you doing this?",
                why: "This gets shown back to you on day 41 at 9pm, when you're tired and looking for a reason to stop. Write the real one."
            ) {
                TextEditor(text: $draft.whyStatement)
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
                    )
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Now name three rewards")
                    .font(.title3.weight(.semibold))
                Text("You'll earn coins for completed days and spend them on these. A reward someone else picked has no pull, so pick your own.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtle)

                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(RewardCatalog.promptQuestions[index])
                            .font(.callout.weight(.medium))
                        TextField("Your answer", text: Binding(
                            get: { draft.rewardAnswers[index] },
                            set: { draft.rewardAnswers[index] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }
}
