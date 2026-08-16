import SwiftUI
import SwiftData
import Charts
import UIKit

struct ProgressTabView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let run: ChallengeRun

    @State private var showPhotos = false

    private var summary: StreakEngine.Summary { StreakEngine.summarise(run: run) }
    private var days: [DayLog] { run.sortedDays }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    overviewCard
                    calendarCard
                    consistencyChart
                    checkInChart
                    taskBreakdown
                    photoTimeline
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Overview

    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                ProgressRing(
                    fraction: run.progressFraction,
                    tint: Theme.tierColor(run.tier),
                    label: "\(run.completedDayCount)",
                    caption: "of \(run.totalDays)"
                )
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 12) {
                    StatLine(symbol: "flame.fill", value: "\(summary.current)", label: "current streak", tint: .orange)
                    StatLine(symbol: "trophy.fill", value: "\(summary.longest)", label: "longest", tint: Theme.coinColor)
                    StatLine(symbol: "percent", value: "\(Int(summary.completionRate * 100))", label: "completion", tint: Theme.success)
                    StatLine(symbol: "snowflake", value: "\(summary.freezesUsed)", label: "freezes used", tint: .blue)
                }
                Spacer(minLength: 0)
            }

            if run.attemptNumber > 1 {
                Text("Attempt \(run.attemptNumber). Everything you did in earlier runs is still recorded.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }

    // MARK: - Calendar heatmap

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "All 75 days", subtitle: "Filled is complete, blue is a freeze.", systemImage: "square.grid.3x3.fill")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10), spacing: 6) {
                ForEach(1...run.totalDays, id: \.self) { number in
                    DayCell(
                        number: number,
                        day: run.day(number: number),
                        isFuture: number > (run.currentDayNumber ?? run.totalDays),
                        tint: Theme.tierColor(run.tier)
                    )
                }
            }
        }
        .card()
    }

    // MARK: - Charts

    private var consistencyChart: some View {
        let points = days.filter { $0.isPast || $0.isComplete }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Completion by day", systemImage: "chart.bar.fill")

            if points.isEmpty {
                Text("A few days in, this fills up.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
            } else {
                Chart(points, id: \.dayNumber) { day in
                    BarMark(
                        x: .value("Day", day.dayNumber),
                        y: .value("Complete", day.completionFraction(against: run.ruleSet) * 100)
                    )
                    .foregroundStyle(day.isComplete ? Theme.success : Theme.warning)
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("% of required tasks")
                .frame(height: 180)
            }
        }
        .card()
    }

    private var checkInChart: some View {
        let points = days.filter(\.hasCheckedIn)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "How you've felt",
                subtitle: "Pain and energy over the run. Worth showing your doctor.",
                systemImage: "waveform.path.ecg"
            )

            if points.count < 2 {
                Text("Two check-ins and this becomes a chart.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
            } else {
                Chart {
                    ForEach(points, id: \.dayNumber) { day in
                        LineMark(
                            x: .value("Day", day.dayNumber),
                            y: .value("Score", day.painScore),
                            series: .value("Metric", "Pain")
                        )
                        .foregroundStyle(Theme.danger)
                        .interpolationMethod(.monotone)
                    }
                    ForEach(points, id: \.dayNumber) { day in
                        LineMark(
                            x: .value("Day", day.dayNumber),
                            y: .value("Score", day.energyScore * 2),
                            series: .value("Metric", "Energy")
                        )
                        .foregroundStyle(Theme.success)
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartForegroundStyleScale([
                    "Pain": Theme.danger,
                    "Energy": Theme.success
                ])
                .frame(height: 180)

                Text("Energy is scaled to the same 0–10 axis as pain.")
                    .font(.caption2)
                    .foregroundStyle(Theme.subtle)
            }
        }
        .card()
    }

    private var taskBreakdown: some View {
        let ruleSet = run.ruleSet
        let settled = days.filter { $0.isPast || $0.isComplete }

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Which task trips you up", systemImage: "list.number")

            if settled.isEmpty {
                Text("Nothing to compare yet.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
            } else {
                ForEach(ruleSet.rules) { rule in
                    let hits = settled.filter { $0.entry(for: rule.id)?.isSatisfied == true }.count
                    let rate = Double(hits) / Double(settled.count)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: rule.iconName)
                                .foregroundStyle(Theme.kindColor(rule.kind))
                                .frame(width: 22)
                            Text(rule.title).font(.callout)
                            Spacer()
                            Text("\(Int(rate * 100))%")
                                .font(.callout.weight(.semibold).monospacedDigit())
                                .foregroundStyle(rate >= 0.8 ? Theme.success : Theme.warning)
                        }
                        ProgressView(value: rate)
                            .tint(rate >= 0.8 ? Theme.success : Theme.warning)
                    }
                }

                if let weakest = weakestRule(ruleSet: ruleSet, settled: settled) {
                    SafetyNote(
                        text: "\(weakest.title) is your weak point. That usually means the target is wrong for your life, not that you lack discipline — open it and check what it's actually asking."
                    )
                }
            }
        }
        .card()
    }

    private func weakestRule(ruleSet: RuleSet, settled: [DayLog]) -> TaskRule? {
        guard settled.count >= 5 else { return nil }
        let scored = ruleSet.requiredRules.map { rule -> (TaskRule, Double) in
            let hits = settled.filter { $0.entry(for: rule.id)?.isSatisfied == true }.count
            return (rule, Double(hits) / Double(settled.count))
        }
        guard let worst = scored.min(by: { $0.1 < $1.1 }), worst.1 < 0.7 else { return nil }
        return worst.0
    }

    // MARK: - Photos

    private var photoTimeline: some View {
        let photoDays = days.filter { $0.photoData != nil }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Photo timeline",
                subtitle: photoDays.isEmpty ? "No photos yet." : "\(photoDays.count) photos, all on this device.",
                systemImage: "photo.stack"
            )

            if !photoDays.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoDays, id: \.dayNumber) { day in
                            if let data = day.photoData, let image = UIImage(data: data) {
                                VStack(spacing: 4) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 128)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text("Day \(day.dayNumber)")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.subtle)
                                }
                            }
                        }
                    }
                }
            }
        }
        .card()
    }
}

struct DayCell: View {
    let number: Int
    let day: DayLog?
    let isFuture: Bool
    let tint: Color

    private var fill: Color {
        guard let day else { return isFuture ? Color(.tertiarySystemBackground) : Theme.danger.opacity(0.25) }
        if day.usedFreezeToken { return .blue.opacity(0.7) }
        if day.isComplete { return tint }
        if day.isPast { return Theme.danger.opacity(0.35) }
        return tint.opacity(0.2)
    }

    var body: some View {
        Text("\(number)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(day?.isComplete == true ? .white : Theme.subtle)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill))
            .accessibilityLabel("Day \(number): \(statusLabel)")
    }

    private var statusLabel: String {
        guard let day else { return isFuture ? "not started" : "missed" }
        if day.usedFreezeToken { return "protected by a freeze" }
        if day.isComplete { return "complete" }
        if day.isPast { return "missed" }
        return "in progress"
    }
}
