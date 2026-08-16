import Foundation
import SwiftData

/// One attempt at the challenge. A restart creates a new run so the history of
/// previous attempts survives — the streak resets, the evidence of effort doesn't.
@Model
final class ChallengeRun {
    var id: UUID = UUID()
    var tierRaw: String = ChallengeTier.medium.rawValue
    var startDate: Date = Date()
    var totalDays: Int = 75
    var isActive: Bool = true
    var endedAt: Date?
    var endReasonRaw: String?

    /// The adapted rules, frozen at the moment the run started.
    var ruleSetData: Data = Data()

    var xp: Int = 0
    var coins: Int = 0
    var freezeTokens: Int = 0
    var restDaysUsed: Int = 0
    var longestStreak: Int = 0

    /// Which attempt this is, for the "third time's the charm" framing.
    var attemptNumber: Int = 1

    @Relationship(deleteRule: .cascade, inverse: \DayLog.run)
    var days: [DayLog] = []

    init(tier: ChallengeTier, ruleSet: RuleSet, startDate: Date = Date(), attemptNumber: Int = 1) {
        self.id = UUID()
        self.tierRaw = tier.rawValue
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.totalDays = 75
        self.isActive = true
        self.ruleSetData = ruleSet.encoded()
        self.attemptNumber = attemptNumber
        self.freezeTokens = ChallengeRun.startingFreezeTokens(for: tier)
    }

    static func startingFreezeTokens(for tier: ChallengeTier) -> Int {
        switch tier {
        case .hard: return 0
        case .medium: return 1
        case .soft: return 3
        }
    }

    // MARK: - Typed accessors

    var tier: ChallengeTier {
        get { ChallengeTier(rawValue: tierRaw) ?? .medium }
        set { tierRaw = newValue.rawValue }
    }

    var endReason: RunEndReason? {
        get { endReasonRaw.flatMap(RunEndReason.init(rawValue:)) }
        set { endReasonRaw = newValue?.rawValue }
    }

    var ruleSet: RuleSet {
        RuleSet.decode(ruleSetData) ?? RuleSet(tier: tier, rules: [])
    }

    // MARK: - Day maths

    /// 1-based day number for a given date, or nil if the date is outside the run.
    func dayNumber(for date: Date) -> Int? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let target = cal.startOfDay(for: date)
        guard let diff = cal.dateComponents([.day], from: start, to: target).day else { return nil }
        guard diff >= 0, diff < totalDays else { return nil }
        return diff + 1
    }

    func date(forDay day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: startDate) ?? startDate
    }

    var currentDayNumber: Int? { dayNumber(for: Date()) }

    var sortedDays: [DayLog] { days.sorted { $0.dayNumber < $1.dayNumber } }

    func day(number: Int) -> DayLog? { days.first { $0.dayNumber == number } }

    var completedDayCount: Int { days.filter(\.isComplete).count }

    var progressFraction: Double {
        guard totalDays > 0 else { return 0 }
        return min(1, Double(completedDayCount) / Double(totalDays))
    }

    var daysRemaining: Int { max(0, totalDays - completedDayCount) }

    var isFinished: Bool { completedDayCount >= totalDays }

    /// Grace days allowed in total under this tier's miss policy.
    var totalGraceDays: Int {
        switch tier.missPolicy {
        case .restart:
            return 0
        case .graceDays(let perBlock, let blockLength):
            return perBlock * Int(ceil(Double(totalDays) / Double(blockLength)))
        case .streakBreakOnly:
            return totalDays
        }
    }
}
