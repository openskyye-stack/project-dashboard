import SwiftUI

/// The morning check-in.
///
/// Four questions, big controls, and an immediate visible consequence — the
/// user sees exactly how the plan changed before they dismiss the sheet. That
/// feedback loop is what makes people answer honestly the next morning.
struct CheckInSheet: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let profile: UserProfile
    let run: ChallengeRun
    let day: DayLog

    @State private var sleepHours: Double = 7
    @State private var painScore: Double = 0
    @State private var energyScore: Double = 3
    @State private var sorenessScore: Double = 1
    @State private var outcome: DayScaler.Outcome?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if let outcome {
                        result(outcome)
                    } else {
                        questions
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(outcome == nil ? "How are you today?" : "Today's plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(outcome == nil ? "Skip" : "Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if outcome == nil {
                    Button {
                        submit()
                    } label: {
                        Text("See today's plan").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(20)
                    .background(.bar)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: - Questions

    private var questions: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Answer honestly. The plan bends to fit — that's the point.")
                .font(.callout)
                .foregroundStyle(Theme.subtle)

            QuestionBlock(question: "How many hours did you sleep?", why: nil) {
                LabelledStepper(
                    value: $sleepHours,
                    range: 0...12,
                    step: 0.5,
                    format: { String(format: "%.1f hours", $0) }
                )
            }

            QuestionBlock(
                question: "Worst pain right now?",
                why: "Above five, the plan halves. Above seven, it becomes range-of-motion work only."
            ) {
                VStack(spacing: 8) {
                    Slider(value: $painScore, in: 0...10, step: 1)
                        .tint(painColor)
                    HStack {
                        Text("None").font(.caption).foregroundStyle(Theme.subtle)
                        Spacer()
                        Text("\(Int(painScore))")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(painColor)
                        Spacer()
                        Text("Unbearable").font(.caption).foregroundStyle(Theme.subtle)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pain level \(Int(painScore)) out of 10")
            }

            QuestionBlock(question: "Energy today?", why: nil) {
                FiveWayPicker(value: $energyScore, lowLabel: "Wiped out", highLabel: "Fresh")
            }

            QuestionBlock(question: "How sore are you from yesterday?", why: nil) {
                FiveWayPicker(value: $sorenessScore, lowLabel: "Fine", highLabel: "Very sore")
            }
        }
    }

    private var painColor: Color {
        switch Int(painScore) {
        case 0...2: return Theme.success
        case 3...5: return Theme.warning
        default: return Theme.danger
        }
    }

    // MARK: - Result

    private func result(_ outcome: DayScaler.Outcome) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(outcome.headline)
                    .font(.largeTitle.bold())
                Text(outcome.reason)
                    .font(.callout)
                    .foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if outcome.scaleFactor < 1 {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Today's targets")
                    ForEach(run.ruleSet.rules) { rule in
                        let scaled = DayScaler.scaledTarget(for: rule, scaleFactor: outcome.scaleFactor)
                        if scaled != rule.target {
                            HStack {
                                Image(systemName: rule.iconName)
                                    .foregroundStyle(Theme.kindColor(rule.kind))
                                    .frame(width: 24)
                                Text(rule.title)
                                Spacer()
                                Text(rule.unit.format(rule.target))
                                    .foregroundStyle(Theme.subtle)
                                    .strikethrough()
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(Theme.subtle)
                                Text(rule.unit.format(scaled))
                                    .font(.body.weight(.semibold))
                            }
                            .font(.callout)
                        }
                    }
                }
                .card(tint: .blue)
            }

            if !outcome.advice.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "For today")
                    ForEach(outcome.advice, id: \.self) { line in
                        Label(line, systemImage: "lightbulb.fill")
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .card()
            }

            if outcome.suggestsRest {
                VStack(alignment: .leading, spacing: 12) {
                    SafetyNote(
                        text: "Today looks like a rest day. A scaled day still counts — but if you'd rather protect the streak and rest properly, spend a freeze.",
                        isCritical: outcome.suggestsClinician
                    )
                    if run.tier != .hard && run.freezeTokens > 0 {
                        Button {
                            store.useFreezeToken(on: day, run: run, profile: profile)
                            dismiss()
                        } label: {
                            Label("Spend a freeze (\(run.freezeTokens) left)", systemImage: "snowflake")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else if run.tier == .hard {
                        Text("75 Hard has no freezes. That's the bargain of the tier — if today is genuinely unsafe, stepping down to 75 Medium in Settings keeps your progress.")
                            .font(.footnote)
                            .foregroundStyle(Theme.subtle)
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Let's go").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Actions

    private func loadExisting() {
        guard day.hasCheckedIn else { return }
        sleepHours = day.sleepHours
        painScore = Double(day.painScore)
        energyScore = Double(day.energyScore)
        sorenessScore = Double(day.sorenessScore)
    }

    private func submit() {
        let checkIn = DayScaler.CheckIn(
            sleepHours: sleepHours,
            painScore: Int(painScore),
            energyScore: Int(energyScore),
            sorenessScore: Int(sorenessScore)
        )
        withAnimation {
            outcome = store.submitCheckIn(day: day, run: run, profile: profile, checkIn: checkIn)
        }
        Haptics.tap()
    }
}

/// Five big buttons instead of a slider — easier to hit accurately and clearer
/// to read at accessibility text sizes.
struct FiveWayPicker: View {
    @Binding var value: Double
    let lowLabel: String
    let highLabel: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { number in
                    Button {
                        Haptics.tap()
                        value = Double(number)
                    } label: {
                        Text("\(number)")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Int(value) == number ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(Int(value) == number ? Color.white : Theme.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(number)")
                    .accessibilityAddTraits(Int(value) == number ? [.isSelected, .isButton] : .isButton)
                }
            }
            HStack {
                Text(lowLabel).font(.caption).foregroundStyle(Theme.subtle)
                Spacer()
                Text(highLabel).font(.caption).foregroundStyle(Theme.subtle)
            }
        }
    }
}
