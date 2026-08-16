import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TodayView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let run: ChallengeRun

    @State private var today: DayLog?
    @State private var showCheckIn = false
    @State private var selectedRule: TaskRule?
    @State private var photoItem: PhotosPickerItem?
    @State private var showWhy = false
    @State private var missedDayToResolve: DayLog?

    private var ruleSet: RuleSet { run.ruleSet }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    if let missed = store.unresolvedMissedDays(for: run).first {
                        MissedDayBanner(day: missed, run: run) {
                            missedDayToResolve = missed
                        }
                    }

                    if let today {
                        if !today.hasCheckedIn {
                            checkInPrompt
                        } else if today.scaleFactor < 1 {
                            scaledBanner(day: today)
                        }

                        taskList(day: today)

                        if ruleSet.rule(id: "photo") != nil {
                            photoCard(day: today)
                        }

                        if ruleSet.rule(id: "reflection") != nil {
                            reflectionCard(day: today)
                        }

                        whyCard
                        stopSignsCard
                    } else {
                        EmptyStateView(
                            title: "Nothing scheduled today",
                            message: run.currentDayNumber == nil
                                ? "This run finished on \(run.date(forDay: run.totalDays).formatted(date: .abbreviated, time: .omitted))."
                                : "Pull to refresh.",
                            systemImage: "calendar"
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Day \(run.currentDayNumber ?? run.completedDayCount)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Label("\(run.coins)", systemImage: "circle.hexagongrid.fill")
                            .foregroundStyle(Theme.coinColor)
                            .font(.callout.weight(.semibold))
                            .accessibilityLabel("\(run.coins) grit coins")
                        if run.freezeTokens > 0 {
                            Label("\(run.freezeTokens)", systemImage: "snowflake")
                                .foregroundStyle(.blue)
                                .font(.callout.weight(.semibold))
                                .accessibilityLabel("\(run.freezeTokens) freeze tokens")
                        }
                    }
                }
            }
            .task { today = store.ensureToday(for: run) }
            .refreshable { today = store.ensureToday(for: run) }
            .sheet(isPresented: $showCheckIn) {
                if let today {
                    CheckInSheet(profile: profile, run: run, day: today)
                }
            }
            .sheet(item: $selectedRule) { rule in
                RuleDetailSheet(rule: rule, profile: profile, run: run, day: today)
            }
            .sheet(item: $missedDayToResolve) { day in
                MissedDayResolutionSheet(day: day, run: run, profile: profile)
            }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue, let today else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        store.setPhoto(data, on: today, run: run, profile: profile)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        let summary = StreakEngine.summarise(run: run)
        let level = XPEngine.level(for: run.xp)
        let fraction = today?.completionFraction(against: ruleSet) ?? 0

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                ProgressRing(
                    fraction: fraction,
                    tint: Theme.tierColor(run.tier),
                    label: "\(Int(fraction * 100))%",
                    caption: "today"
                )
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: run.tier.accentSymbol)
                        Text(run.tier.displayName).font(.headline)
                    }
                    .foregroundStyle(Theme.tierColor(run.tier))

                    StatLine(symbol: "flame.fill", value: "\(summary.current)", label: "day streak", tint: .orange)
                    StatLine(symbol: "checkmark.circle.fill", value: "\(run.completedDayCount)/\(run.totalDays)", label: "complete", tint: Theme.success)
                    StatLine(symbol: level.symbol, value: "Lv \(level.index)", label: level.title, tint: .purple)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(level.title) · \(run.xp) XP").font(.caption.weight(.medium))
                    Spacer()
                    if let next = level.xpToNext {
                        Text("\(next) XP to level \(level.index + 1)")
                            .font(.caption)
                            .foregroundStyle(Theme.subtle)
                    }
                }
                ProgressView(value: max(0, min(1, level.progress)))
                    .tint(.purple)
            }
        }
        .card()
    }

    // MARK: - Check-in

    private var checkInPrompt: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sun.horizon.fill")
                    .font(.title)
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Morning check-in")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Four questions. Today's targets adjust to your answers.")
                        .font(.footnote)
                        .foregroundStyle(Theme.subtle)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.subtle)
            }
            .card(tint: Theme.warning)
        }
        .buttonStyle(.plain)
    }

    private func scaledBanner(day: DayLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.right.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Scaled to \(Int(day.scaleFactor * 100))% today")
                    .font(.subheadline.weight(.semibold))
                Text(day.scaleReason)
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Redo") { showCheckIn = true }
                .font(.footnote.weight(.medium))
        }
        .card(tint: .blue)
    }

    // MARK: - Tasks

    private func taskList(day: DayLog) -> some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Today's tasks", subtitle: "Tap the circle to finish, plus to log part of it.")

            ForEach(ruleSet.rules) { rule in
                if rule.id == "photo" || rule.id == "reflection" { EmptyView() } else {
                    TaskCard(
                        rule: rule,
                        entry: day.entry(for: rule.id),
                        onIncrement: { store.log(rule: rule, amount: rule.unit.step, on: day, run: run, profile: profile) },
                        onDecrement: { store.log(rule: rule, amount: -rule.unit.step, on: day, run: run, profile: profile) },
                        onToggle: { store.toggle(rule: rule, on: day, run: run, profile: profile) },
                        onDetail: { selectedRule = rule }
                    )
                }
            }
        }
    }

    // MARK: - Photo

    private func photoCard(day: DayLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Progress photo", subtitle: "Stored on this device only. Never uploaded.", systemImage: "camera.fill")

            if let data = day.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(role: .destructive) {
                    store.setPhoto(nil, on: day, run: run, profile: profile)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .font(.footnote)
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Add today's photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Theme.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .card()
    }

    // MARK: - Reflection

    private func reflectionCard(day: DayLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "One line about today", systemImage: "text.book.closed.fill")

            TextField("What worked, what hurt, what you'd change", text: Binding(
                get: { day.reflection },
                set: { store.setReflection($0, on: day, run: run, profile: profile) }
            ), axis: .vertical)
            .lineLimit(2...5)
            .textFieldStyle(.roundedBorder)
        }
        .card()
    }

    // MARK: - Why

    @ViewBuilder
    private var whyCard: some View {
        if !profile.whyStatement.trimmingCharacters(in: .whitespaces).isEmpty {
            Button {
                withAnimation { showWhy.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Why you're doing this", systemImage: "quote.opening")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: showWhy ? "chevron.up" : "chevron.down")
                    }
                    .foregroundStyle(Theme.subtle)

                    if showWhy {
                        Text(profile.whyStatement)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    private var stopSignsCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(MobilityAdaptation.stopSigns, id: \.self) { sign in
                    Label(sign, systemImage: "octagon.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.ink)
                }
                Text("Any of these means stop and seek advice. No streak is worth a cardiac event.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
                    .padding(.top, 4)
            }
            .padding(.top, 8)
        } label: {
            Label("Stop immediately if…", systemImage: "exclamationmark.octagon.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.danger)
        }
        .card()
    }
}

// MARK: - Small pieces

struct StatLine: View {
    let symbol: String
    let value: String
    let label: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(value).font(.callout.weight(.semibold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(Theme.subtle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

struct MissedDayBanner: View {
    let day: DayLog
    let run: ChallengeRun
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.danger)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Day \(day.dayNumber) ended incomplete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Tap to decide what happens next.")
                        .font(.footnote)
                        .foregroundStyle(Theme.subtle)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.subtle)
            }
            .card(tint: Theme.danger)
        }
        .buttonStyle(.plain)
    }
}
