import Foundation
import SwiftData

/// One day of the challenge, including the morning check-in that decides how
/// hard the app is allowed to push today.
@Model
final class DayLog {
    var dayNumber: Int = 1
    var date: Date = Date()

    var run: ChallengeRun?

    @Relationship(deleteRule: .cascade, inverse: \TaskEntry.day)
    var entries: [TaskEntry] = []

    // Morning check-in
    var hasCheckedIn: Bool = false
    var sleepHours: Double = 7
    /// 0–10 self-reported worst pain right now.
    var painScore: Int = 0
    /// 1–5, where 1 is wiped out and 5 is fresh.
    var energyScore: Int = 3
    /// 1–5 muscle soreness from yesterday.
    var sorenessScore: Int = 1
    var moodNote: String = ""

    /// What the check-in decided: 1.0 is the full plan, lower is a deliberate deload.
    var scaleFactor: Double = 1.0
    var scaleReason: String = ""

    // Outcome
    var isComplete: Bool = false
    var completedAt: Date?
    var usedFreezeToken: Bool = false
    var isPlannedRestDay: Bool = false
    /// Set once the user has decided what to do about a missed day, so the
    /// banner stops asking. A day can be missed and settled at the same time.
    var missAcknowledged: Bool = false
    var xpEarned: Int = 0
    var coinsEarned: Int = 0

    /// Progress photo, stored externally so the database stays small.
    @Attribute(.externalStorage) var photoData: Data?

    var reflection: String = ""

    init(dayNumber: Int, date: Date) {
        self.dayNumber = dayNumber
        self.date = Calendar.current.startOfDay(for: date)
    }

    // MARK: - Derived

    func entry(for ruleID: String) -> TaskEntry? {
        entries.first { $0.ruleID == ruleID }
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }

    /// A day counts as done when every required task is satisfied, or when a
    /// freeze token has been spent on it.
    func evaluateCompletion(against ruleSet: RuleSet) -> Bool {
        if usedFreezeToken { return true }
        let required = ruleSet.requiredRules
        guard !required.isEmpty else { return false }
        return required.allSatisfy { rule in
            entry(for: rule.id)?.isSatisfied ?? false
        }
    }

    func completionFraction(against ruleSet: RuleSet) -> Double {
        let required = ruleSet.requiredRules
        guard !required.isEmpty else { return 0 }
        let total = required.reduce(0.0) { partial, rule in
            let entry = entry(for: rule.id)
            return partial + (entry?.fraction ?? 0)
        }
        return min(1, total / Double(required.count))
    }

    /// True once the day is over and it was not completed — the trigger for the
    /// tier's miss policy.
    func isMissed(against ruleSet: RuleSet) -> Bool {
        isPast && !isComplete && !evaluateCompletion(against: ruleSet)
    }

    /// A missed day the user hasn't yet decided about.
    func needsMissResolution(against ruleSet: RuleSet) -> Bool {
        !missAcknowledged && isMissed(against: ruleSet)
    }
}

/// Progress against one rule on one day.
@Model
final class TaskEntry {
    var ruleID: String = ""
    var value: Double = 0
    var target: Double = 1
    var isManuallyComplete: Bool = false
    var completedAt: Date?
    var note: String = ""
    /// Number of separate chunks logged, for rules that may be split.
    var splitCount: Int = 0

    var day: DayLog?

    init(ruleID: String, target: Double) {
        self.ruleID = ruleID
        self.target = target
    }

    var fraction: Double {
        if isManuallyComplete { return 1 }
        guard target > 0 else { return 0 }
        return min(1, value / target)
    }

    var isSatisfied: Bool {
        isManuallyComplete || (target > 0 && value >= target)
    }

    func add(_ amount: Double) {
        value = max(0, value + amount)
        if amount > 0 { splitCount += 1 }
        refreshCompletionStamp()
    }

    func set(_ amount: Double) {
        value = max(0, amount)
        refreshCompletionStamp()
    }

    func toggleManualCompletion() {
        isManuallyComplete.toggle()
        if isManuallyComplete {
            value = max(value, target)
        } else if value >= target {
            value = 0
            splitCount = 0
        }
        refreshCompletionStamp()
    }

    private func refreshCompletionStamp() {
        if isSatisfied {
            if completedAt == nil { completedAt = Date() }
        } else {
            completedAt = nil
        }
    }
}
