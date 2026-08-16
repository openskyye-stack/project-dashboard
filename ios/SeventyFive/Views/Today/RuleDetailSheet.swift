import SwiftUI

/// Everything behind a task: what it's asking, why it's set at that number, how
/// to actually do it today, and what to stop for.
struct RuleDetailSheet: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let rule: TaskRule
    let profile: UserProfile
    let run: ChallengeRun
    let day: DayLog?

    @State private var customAmount: Double = 0

    private var entry: TaskEntry? { day?.entry(for: rule.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headline

                    if !rule.adaptations.isEmpty {
                        adaptationsSection
                    }

                    if isMovement {
                        optionsSection
                    }

                    if rule.kind == .hydration {
                        hydrationSection
                    }

                    if !rule.safetyFlags.isEmpty || isMovement {
                        safetySection
                    }

                    if !rule.isBinary {
                        quickLogSection
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(rule.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var isMovement: Bool {
        switch rule.kind {
        case .workout, .outdoorWorkout, .movementSnack, .balanceWork, .mobilityWork: return true
        default: return false
        }
    }

    // MARK: - Sections

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: rule.iconName)
                    .font(.title)
                    .foregroundStyle(Theme.kindColor(rule.kind))
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.targetDescription)
                        .font(.title2.weight(.bold))
                    if let entry {
                        Text("\(rule.unit.format(entry.value)) logged")
                            .font(.footnote)
                            .foregroundStyle(Theme.subtle)
                    }
                }
            }
            Text(rule.detail)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if let chunk = rule.chunkDescription {
                TagPill(text: chunk, systemImage: "square.split.2x1", tint: .blue)
            }
        }
        .card(tint: Theme.kindColor(rule.kind))
    }

    private var adaptationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Why this number",
                subtitle: "Adapted from the standard rule for your answers.",
                systemImage: "slider.horizontal.3"
            )
            ForEach(rule.adaptations, id: \.self) { note in
                Label {
                    Text(note).font(.footnote).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(Theme.subtle)
                }
            }
        }
        .card()
    }

    private var optionsSection: some View {
        let outdoorOnly = rule.kind == .outdoorWorkout
        let options = MobilityAdaptation.options(for: profile, outdoorOnly: outdoorOnly)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Ways to do this today",
                subtitle: "Filtered to what's safe and possible with your equipment.",
                systemImage: "list.bullet"
            )

            if options.isEmpty {
                Text("No stored options match your profile. Anything continuous and conversational counts.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
            } else {
                ForEach(options) { option in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: option.symbolName)
                            .font(.title3)
                            .foregroundStyle(Theme.kindColor(rule.kind))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title).font(.body.weight(.medium))
                            Text(option.detail)
                                .font(.footnote)
                                .foregroundStyle(Theme.subtle)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 6) {
                                if option.isSeated { TagPill(text: "seated", tint: .teal) }
                                if option.isLowImpact { TagPill(text: "low impact", tint: Theme.success) }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if option.id != options.last?.id { Divider() }
                }
            }
        }
        .card()
    }

    private var hydrationSection: some View {
        let result = HydrationCalculator.dailyTarget(for: profile, tier: run.tier)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Your water target", systemImage: "drop.fill")

            Text("\(HydrationFormatter.short(milliliters: result.targetML)) — about \(result.glassCount) glasses.")
                .font(.callout.weight(.medium))

            ForEach(result.notes, id: \.self) { note in
                Text("• \(note)")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if result.requiresClinicianInput {
                SafetyNote(
                    text: "You told us your fluids are limited. This number is a conservative cap, not a prescription — get the real one from your clinician and set it in Settings.",
                    isCritical: true
                )
            }
        }
        .card()
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Safety", systemImage: "shield.fill")

            ForEach(rule.safetyFlags, id: \.self) { flag in
                Label(flag, systemImage: "checkmark.shield")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isMovement {
                Divider()
                Text("Stop immediately for:")
                    .font(.footnote.weight(.semibold))
                ForEach(MobilityAdaptation.stopSigns, id: \.self) { sign in
                    Label(sign, systemImage: "octagon.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .card(tint: Theme.warning)
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Log an amount", systemImage: "plus.circle")

            LabelledStepper(
                value: $customAmount,
                range: 0...(rule.target * 2),
                step: rule.unit.step,
                format: { rule.unit.format($0) }
            )

            Button {
                guard let day, customAmount > 0 else { return }
                store.log(rule: rule, amount: customAmount, on: day, run: run, profile: profile)
                customAmount = 0
                dismiss()
            } label: {
                Text("Add to today").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(customAmount <= 0 || day == nil)
        }
        .card()
    }
}

/// What happens when a day ends unfinished. The options differ by tier, and the
/// consequences are stated plainly rather than softened.
struct MissedDayResolutionSheet: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let day: DayLog
    let run: ChallengeRun
    let profile: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Day \(day.dayNumber) ended incomplete")
                        .font(.title.bold())

                    switch StreakEngine.resolveMiss(run: run, missedDay: day) {
                    case .restartRequired(let daysLost):
                        restartOptions(daysLost: daysLost)
                    case .graceAvailable(let remaining):
                        graceOptions(remaining: remaining)
                    case .streakBroken:
                        softOptions
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    private func restartOptions(daysLost: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("75 Hard's rule is a restart. You'd go back to day 1 and lose \(daysLost) completed \(daysLost == 1 ? "day" : "days") of streak — but not the record of them.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            SafetyNote(
                text: "Before you restart: was this a discipline problem or a design problem? If the plan is asking for more than your body can give on an average day, restarting the same plan gets the same result. Stepping down a tier keeps every day you've done.",
                isCritical: false
            )

            Button(role: .destructive) {
                store.acknowledgeMiss(on: day)
                store.restart(run: run, profile: profile)
                dismiss()
            } label: {
                Label("Restart at day 1", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let gentler = run.tier.gentler {
                Button {
                    store.acknowledgeMiss(on: day)
                    store.restart(run: run, profile: profile, tier: gentler)
                    dismiss()
                } label: {
                    Label("Switch to \(gentler.displayName) and continue", systemImage: "arrow.down.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private func graceOptions(remaining: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You have \(remaining) grace \(remaining == 1 ? "day" : "days") left on \(run.tier.displayName). Spending one keeps the streak and the run intact.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.useFreezeToken(on: day, run: run, profile: profile)
                store.acknowledgeMiss(on: day)
                dismiss()
            } label: {
                Label("Spend a grace day", systemImage: "snowflake")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                store.acknowledgeMiss(on: day)
                dismiss()
            } label: {
                Text("Take the streak break").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var softOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("On 75 Soft nothing resets. Your streak counter goes back to zero and the run carries on from today.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Text("Missing one day in seventy-five changes nothing about the outcome. Missing three in a row is the signal worth paying attention to.")
                .font(.footnote)
                .foregroundStyle(Theme.subtle)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.acknowledgeMiss(on: day)
                dismiss()
            } label: {
                Text("Carry on").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
