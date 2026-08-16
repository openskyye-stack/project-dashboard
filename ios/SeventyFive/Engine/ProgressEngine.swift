import Foundation

// MARK: - Streaks

enum StreakEngine {

    struct Summary {
        var current: Int
        var longest: Int
        var completedDays: Int
        var missedDays: Int
        var freezesUsed: Int
        var completionRate: Double
    }

    static func summarise(run: ChallengeRun) -> Summary {
        let days = run.sortedDays

        var current = 0
        var longest = 0
        var running = 0
        var missed = 0
        var freezes = 0

        for day in days {
            if day.isComplete {
                running += 1
                longest = max(longest, running)
                if day.usedFreezeToken { freezes += 1 }
            } else if day.isPast {
                missed += 1
                running = 0
            }
        }

        // The current streak runs backwards from the most recent settled day.
        for day in days.reversed() {
            if day.isComplete {
                current += 1
            } else if day.isToday {
                continue // today is still open, it doesn't break anything yet
            } else {
                break
            }
        }

        let completed = days.filter(\.isComplete).count
        let settled = days.filter { $0.isPast || $0.isComplete }.count
        let rate = settled > 0 ? Double(completed) / Double(settled) : 0

        return Summary(
            current: current,
            longest: max(longest, run.longestStreak),
            completedDays: completed,
            missedDays: missed,
            freezesUsed: freezes,
            completionRate: rate
        )
    }

    /// What the app should do about a day that ended incomplete.
    enum MissResolution: Equatable {
        case restartRequired(daysLost: Int)
        case graceAvailable(remaining: Int)
        case streakBroken
    }

    static func resolveMiss(run: ChallengeRun, missedDay: DayLog) -> MissResolution {
        switch run.tier.missPolicy {
        case .restart:
            return .restartRequired(daysLost: max(0, missedDay.dayNumber - 1))
        case .graceDays:
            let used = run.days.filter(\.usedFreezeToken).count
            let remaining = max(0, run.totalGraceDays - used)
            return remaining > 0 ? .graceAvailable(remaining: remaining) : .restartRequired(daysLost: max(0, missedDay.dayNumber - 1))
        case .streakBreakOnly:
            return .streakBroken
        }
    }
}

// MARK: - XP and levels

enum XPEngine {

    /// Level thresholds. Deliberately front-loaded: the first few levels come
    /// fast because that's when people quit.
    static let levelTitles: [(minXP: Int, title: String, symbol: String)] = [
        (0, "Starting Out", "circle"),
        (100, "Showing Up", "figure.walk"),
        (300, "Building", "hammer.fill"),
        (700, "Consistent", "checkmark.seal.fill"),
        (1300, "Steady Hand", "hand.raised.fill"),
        (2200, "Relentless", "flame.fill"),
        (3500, "Unshakeable", "shield.fill"),
        (5200, "Iron Habit", "bolt.shield.fill"),
        (7500, "Veteran", "rosette"),
        (10500, "Legend", "crown.fill")
    ]

    struct Level {
        var index: Int
        var title: String
        var symbol: String
        var currentXP: Int
        var floorXP: Int
        var ceilingXP: Int?

        var progress: Double {
            guard let ceiling = ceilingXP, ceiling > floorXP else { return 1 }
            return Double(currentXP - floorXP) / Double(ceiling - floorXP)
        }

        var xpToNext: Int? {
            guard let ceiling = ceilingXP else { return nil }
            return max(0, ceiling - currentXP)
        }
    }

    static func level(for xp: Int) -> Level {
        var index = 0
        for (i, entry) in levelTitles.enumerated() where xp >= entry.minXP {
            index = i
        }
        let entry = levelTitles[index]
        let ceiling = index + 1 < levelTitles.count ? levelTitles[index + 1].minXP : nil
        return Level(
            index: index + 1,
            title: entry.title,
            symbol: entry.symbol,
            currentXP: xp,
            floorXP: entry.minXP,
            ceilingXP: ceiling
        )
    }

    /// Streak multiplier, capped so that a long streak doesn't make early days
    /// feel worthless — and so a break doesn't feel catastrophic.
    static func streakMultiplier(streak: Int) -> Double {
        switch streak {
        case 0...2: return 1.0
        case 3...6: return 1.1
        case 7...13: return 1.25
        case 14...29: return 1.4
        case 30...49: return 1.6
        default: return 1.75
        }
    }

    struct DayAward {
        var taskXP: Int
        var completionBonus: Int
        var multiplier: Double
        var totalXP: Int
        var coins: Int
        var freezeTokenEarned: Bool
    }

    /// XP is awarded for what you did, not for what the plan said. A deload day
    /// completed in full is worth full credit — that's the whole point of the
    /// adaptive design.
    static func award(day: DayLog, ruleSet: RuleSet, streak: Int, tier: ChallengeTier) -> DayAward {
        var taskXP = 0
        for rule in ruleSet.rules {
            guard let entry = day.entry(for: rule.id) else { continue }
            if entry.isSatisfied {
                taskXP += rule.xpValue
            } else if rule.allowsPartialCredit {
                taskXP += Int(Double(rule.xpValue) * entry.fraction * 0.5)
            }
        }

        let complete = day.evaluateCompletion(against: ruleSet)
        let bonus = complete ? tierBonus(tier) : 0
        let multiplier = complete ? streakMultiplier(streak: streak) : 1.0
        let total = Int((Double(taskXP + bonus) * multiplier).rounded())

        // Coins are the reward currency and are only earned on complete days,
        // so the shop can't be farmed by half-finishing eight days in a row.
        var coins = complete ? 10 : 0
        if complete && day.dayNumber % 7 == 0 { coins += 15 }   // weekly bonus
        if complete && day.scaleFactor < 1 { coins += 2 }        // showed up anyway

        // A freeze token every 10 completed days, for tiers that allow them.
        let earnsFreeze = complete && tier != .hard && day.dayNumber % 10 == 0

        return DayAward(
            taskXP: taskXP,
            completionBonus: bonus,
            multiplier: multiplier,
            totalXP: total,
            coins: coins,
            freezeTokenEarned: earnsFreeze
        )
    }

    private static func tierBonus(_ tier: ChallengeTier) -> Int {
        switch tier {
        case .hard: return 40
        case .medium: return 30
        case .soft: return 25
        }
    }
}

// MARK: - Achievements

enum AchievementEngine {

    /// Evaluates the whole catalogue and returns codes that are newly satisfied.
    static func newlyUnlocked(
        run: ChallengeRun,
        profile: UserProfile,
        alreadyUnlocked: Set<String>,
        redemptionCount: Int,
        plannedMealCount: Int
    ) -> [Achievement] {
        let summary = StreakEngine.summarise(run: run)
        let days = run.sortedDays
        let completed = days.filter(\.isComplete)

        var earned: [String] = []

        func check(_ code: String, _ condition: @autoclosure () -> Bool) {
            guard !alreadyUnlocked.contains(code) else { return }
            if condition() { earned.append(code) }
        }

        check("first.day", summary.completedDays >= 1)
        check("week.one", summary.current >= 7 || summary.longest >= 7)
        check("day.25", summary.completedDays >= 25)
        check("day.50", summary.completedDays >= 50)
        check("day.75", summary.completedDays >= 75)
        check("streak.14", summary.longest >= 14)
        check("streak.30", summary.longest >= 30)

        check("hydration.perfect.week", hasPerfectRun(days: completed, ruleID: "hydration", length: 7))
        check("reading.perfect.week", hasPerfectRun(days: completed, ruleID: "reading", length: 7))

        check("deload.hero", completed.contains { $0.scaleFactor < 1.0 })
        check("deload.veteran", completed.filter { $0.scaleFactor <= 0.6 }.count >= 5)

        check("early.bird", completed.contains { day in
            guard let stamp = day.completedAt else { return false }
            return Calendar.current.component(.hour, from: stamp) < 9
        })

        check("meal.planner", plannedMealCount >= 7)
        check("meal.architect", plannedMealCount >= 30)
        check("reward.claimed", redemptionCount >= 1)
        check("photo.streak", consecutivePhotos(days: days) >= 10)

        check("comeback", run.attemptNumber >= 2 && summary.completedDays >= 7)
        check("balance.builder", days.contains { $0.entry(for: "balance.daily")?.isSatisfied == true }
              && completed.filter { $0.entry(for: "balance.daily")?.isSatisfied == true }.count >= 20)

        check("no.freeze", summary.completedDays >= 30 && summary.freezesUsed == 0)
        check("honest.log", days.filter(\.hasCheckedIn).count >= 30)
        check("age.is.a.number", profile.age >= 65 && summary.completedDays >= 30)

        let catalogue = AchievementCatalog.byCode
        return earned.compactMap { catalogue[$0] }
    }

    private static func hasPerfectRun(days: [DayLog], ruleID: String, length: Int) -> Bool {
        let sorted = days.sorted { $0.dayNumber < $1.dayNumber }
        guard sorted.count >= length else { return false }
        var streak = 0
        for day in sorted {
            if day.entry(for: ruleID)?.isSatisfied == true {
                streak += 1
                if streak >= length { return true }
            } else {
                streak = 0
            }
        }
        return false
    }

    private static func consecutivePhotos(days: [DayLog]) -> Int {
        var best = 0
        var running = 0
        for day in days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            if day.photoData != nil {
                running += 1
                best = max(best, running)
            } else if day.isPast {
                running = 0
            }
        }
        return best
    }
}
