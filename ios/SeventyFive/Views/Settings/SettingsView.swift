import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let run: ChallengeRun

    @State private var showProfileEditor = false
    @State private var showPlan = false
    @State private var showTierChange = false
    @State private var showResetConfirm = false
    @State private var hapticsOn = Haptics.isEnabled
    @State private var notificationsAuthorised = false

    var body: some View {
        NavigationStack {
            Form {
                runSection
                planSection
                accessibilitySection
                remindersSection
                safetySection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditor(profile: profile, run: run)
            }
            .sheet(isPresented: $showPlan) {
                PlanSummarySheet(profile: profile, run: run)
            }
            .confirmationDialog(
                "Change tier?",
                isPresented: $showTierChange,
                titleVisibility: .visible
            ) {
                ForEach(ChallengeTier.allCases.filter { $0 != run.tier }) { tier in
                    Button(tier.displayName) {
                        store.restart(run: run, profile: profile, tier: tier)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This starts a fresh run at day 1 on the new tier. Your current run is kept in your history, not deleted.")
            }
            .alert("Erase everything?", isPresented: $showResetConfirm) {
                Button("Erase", role: .destructive) { store.deleteEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every run, photo, recipe and reward on this device is deleted. There is no backup and no undo.")
            }
            .task {
                notificationsAuthorised = await NotificationManager.shared.authorizationStatus() == .authorized
            }
        }
    }

    // MARK: - Sections

    private var runSection: some View {
        Section("Current run") {
            LabeledContent("Tier") {
                Label(run.tier.displayName, systemImage: run.tier.accentSymbol)
                    .foregroundStyle(Theme.tierColor(run.tier))
            }
            LabeledContent("Started", value: run.startDate.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Day", value: "\(run.currentDayNumber ?? run.completedDayCount) of \(run.totalDays)")
            LabeledContent("Attempt", value: "\(run.attemptNumber)")

            Button {
                showTierChange = true
            } label: {
                Label("Change tier", systemImage: "arrow.up.arrow.down")
            }

            if run.tier == .hard {
                Text("Stepping down to 75 Medium is a strategy, not a failure. Most people who finish did not finish their first attempt at the hardest tier.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
            }
        }
    }

    private var planSection: some View {
        Section("Your plan") {
            Button {
                showPlan = true
            } label: {
                Label("See today's rules and why", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                showProfileEditor = true
            } label: {
                Label("Update my answers", systemImage: "person.text.rectangle")
            }

            Button {
                store.readaptRules(run: run, profile: profile)
                Haptics.complete()
            } label: {
                Label("Re-adapt the plan to my answers", systemImage: "wand.and.stars")
            }

            Text("Re-adapting rewrites the targets for the rest of this run using your current answers. Days you've already completed are untouched.")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
        }
    }

    private var accessibilitySection: some View {
        Section("Accessibility") {
            Toggle("Larger text everywhere", isOn: Binding(
                get: { profile.wantsLargeText },
                set: { profile.wantsLargeText = $0; store.save() }
            ))
            Toggle("Reduce animation", isOn: Binding(
                get: { profile.wantsReducedMotion },
                set: { profile.wantsReducedMotion = $0; store.save() }
            ))
            Toggle("Haptic feedback", isOn: Binding(
                get: { hapticsOn },
                set: { hapticsOn = $0; Haptics.setEnabled($0) }
            ))
            Text("The app also follows the system text size and VoiceOver settings — this is on top of those.")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            LabeledContent("Notifications") {
                Text(notificationsAuthorised ? "On" : "Off")
                    .foregroundStyle(notificationsAuthorised ? Theme.success : Theme.subtle)
            }

            if !notificationsAuthorised {
                Button {
                    Task {
                        notificationsAuthorised = await NotificationManager.shared.requestAuthorization()
                        if notificationsAuthorised {
                            await NotificationManager.shared.rescheduleAll(profile: profile, ruleSet: run.ruleSet)
                        }
                    }
                } label: {
                    Label("Turn on reminders", systemImage: "bell.badge")
                }
            }

            Picker("Up at", selection: Binding(
                get: { profile.preferredStartHour },
                set: { profile.preferredStartHour = $0; store.save(); reschedule() }
            )) {
                ForEach(0..<24, id: \.self) { Text(HourPicker.label(for: $0)).tag($0) }
            }

            Picker("Winding down at", selection: Binding(
                get: { profile.preferredWindDownHour },
                set: { profile.preferredWindDownHour = $0; store.save(); reschedule() }
            )) {
                ForEach(0..<24, id: \.self) { Text(HourPicker.label(for: $0)).tag($0) }
            }

            Text("Water reminders sit between these two and stop two hours before you wind down.")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
        }
    }

    private var safetySection: some View {
        Section("Safety") {
            if profile.shouldPromptClinicianCheck {
                SafetyNote(
                    text: "Based on your answers, this plan should be reviewed by a clinician. Show them the rules page — it's specific enough to be useful.",
                    isCritical: true
                )
            }

            Toggle("A clinician has cleared me", isOn: Binding(
                get: { profile.clinicianCleared },
                set: { profile.clinicianCleared = $0; store.save() }
            ))

            ForEach(profile.safetyNotes, id: \.self) { note in
                Label(note, systemImage: "shield.lefthalf.filled")
                    .font(.footnote)
            }

            DisclosureGroup("Stop immediately if…") {
                ForEach(MobilityAdaptation.stopSigns, id: \.self) { sign in
                    Label(sign, systemImage: "octagon.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            LabeledContent("Where it lives", value: "This device only")
            Text("No account, no server, no analytics. Progress photos never leave your phone. Deleting the app deletes everything with it.")
                .font(.caption)
                .foregroundStyle(Theme.subtle)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Erase everything", systemImage: "trash")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Text("75 Hard is a challenge created by Andy Frisella. This app is not affiliated with it. The Medium and Soft tiers are community variants, and every tier here is further adapted to your answers.")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
            Text("Nothing in this app is medical advice.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.subtle)
        } header: {
            Text("About")
        }
    }

    private func reschedule() {
        Task { await NotificationManager.shared.rescheduleAll(profile: profile, ruleSet: run.ruleSet) }
    }
}

// MARK: - Plan summary

/// The page to take to a doctor's appointment.
struct PlanSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    let run: ChallengeRun

    private var ruleSet: RuleSet { run.ruleSet }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(run.tier.displayName), adapted")
                            .font(.title2.bold())
                        Text("\(profile.displayName), age \(profile.age) · \(profile.mobility.displayName.lowercased())")
                            .font(.footnote)
                            .foregroundStyle(Theme.subtle)
                    }

                    ForEach(ruleSet.rules) { rule in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: rule.iconName)
                                    .foregroundStyle(Theme.kindColor(rule.kind))
                                Text(rule.title).font(.headline)
                                Spacer()
                                Text(rule.targetDescription)
                                    .font(.callout.weight(.semibold))
                            }
                            Text(rule.detail)
                                .font(.footnote)
                                .foregroundStyle(Theme.subtle)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(rule.adaptations, id: \.self) { note in
                                Text("• \(note)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.subtle)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(rule.safetyFlags, id: \.self) { flag in
                                Text("⚠︎ \(flag)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .card()
                    }

                    ForEach(ruleSet.globalNotes, id: \.self) { note in
                        SafetyNote(text: note, isCritical: note.lowercased().contains("doctor"))
                    }

                    if !profile.safetyNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Condition-specific notes")
                            ForEach(profile.safetyNotes, id: \.self) { note in
                                Label(note, systemImage: "shield.lefthalf.filled")
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .card()
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Profile editor

struct ProfileEditor: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let profile: UserProfile
    let run: ChallengeRun

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Name", text: Binding(
                        get: { profile.name },
                        set: { profile.name = $0 }
                    ))
                    Stepper("Born \(profile.birthYear)", value: Binding(
                        get: { profile.birthYear },
                        set: { profile.birthYear = $0 }
                    ), in: 1900...2010)
                    LabeledContent("Age", value: "\(profile.age)")
                }

                Section("Body") {
                    LabelledStepper(
                        value: Binding(get: { profile.weightKg }, set: { profile.weightKg = $0 }),
                        range: 35...200, step: 1, format: { "\(Int($0)) kg" }
                    )
                    LabelledStepper(
                        value: Binding(get: { profile.heightCm }, set: { profile.heightCm = $0 }),
                        range: 120...220, step: 1, format: { "\(Int($0)) cm" }
                    )
                }

                Section("Moving around") {
                    Picker("Mobility", selection: Binding(
                        get: { profile.mobility },
                        set: { profile.mobility = $0 }
                    )) {
                        ForEach(MobilityLevel.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Joint pain", selection: Binding(
                        get: { profile.jointPain },
                        set: { profile.jointPain = $0 }
                    )) {
                        ForEach(PainLevel.allCases) { Text($0.displayName).tag($0) }
                    }
                    Stepper("Balance confidence: \(profile.balanceConfidence)/5", value: Binding(
                        get: { profile.balanceConfidence },
                        set: { profile.balanceConfidence = $0 }
                    ), in: 1...5)
                    Toggle("Fallen in the last year", isOn: Binding(
                        get: { profile.hasFallenInLastYear },
                        set: { profile.hasFallenInLastYear = $0 }
                    ))
                    LabelledStepper(
                        value: Binding(
                            get: { Double(profile.continuousStandingMinutes) },
                            set: { profile.continuousStandingMinutes = Int($0) }
                        ),
                        range: 0...90, step: 5,
                        format: { $0 <= 0 ? "Seated exercise" : "\(Int($0)) min standing" }
                    )
                }

                Section("Your day") {
                    LabelledStepper(
                        value: Binding(
                            get: { Double(profile.availableMinutesPerDay) },
                            set: { profile.availableMinutesPerDay = Int($0) }
                        ),
                        range: 30...180, step: 10,
                        format: { "\(Int($0)) min available" }
                    )
                    Picker("Outdoor access", selection: Binding(
                        get: { profile.outdoorAccess },
                        set: { profile.outdoorAccess = $0 }
                    )) {
                        ForEach(OutdoorAccess.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Reading", selection: Binding(
                        get: { profile.readingFormat },
                        set: { profile.readingFormat = $0 }
                    )) {
                        ForEach(ReadingFormat.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section("Why you're doing this") {
                    TextField("Your reason", text: Binding(
                        get: { profile.whyStatement },
                        set: { profile.whyStatement = $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                Section {
                    Text("Saving updates your profile. To push these changes into your current run's targets, use \"Re-adapt the plan\" on the settings screen.")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
            }
            .navigationTitle("Your answers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        profile.updatedAt = Date()
                        store.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
