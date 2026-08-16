import Foundation
import Observation
import SwiftData

/// The one place that mutates challenge state.
///
/// Views read with `@Query` and write through here, so the rules about XP,
/// coins, streaks and achievements live in exactly one file.
@MainActor
@Observable
final class ChallengeStore {

    var context: ModelContext

    /// Set when something worth celebrating happens, so the UI can react once
    /// and then clear it.
    var pendingCelebration: Celebration?

    struct Celebration: Identifiable {
        var id = UUID()
        var title: String
        var message: String
        var symbolName: String
        var coins: Int
        var achievements: [Achievement]
    }

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Fetching

    func activeProfile() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor))?.first
    }

    func activeRun() -> ChallengeRun? {
        let descriptor = FetchDescriptor<ChallengeRun>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    func allRuns() -> [ChallengeRun] {
        let descriptor = FetchDescriptor<ChallengeRun>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func allRecipes() -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func unlockedAchievementCodes() -> Set<String> {
        let descriptor = FetchDescriptor<AchievementRecord>()
        let records = (try? context.fetch(descriptor)) ?? []
        return Set(records.map(\.code))
    }

    // MARK: - First launch

    /// Seeds the recipe library and starter rewards exactly once.
    func seedIfNeeded() {
        let recipeCount = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
        if recipeCount == 0 {
            for recipe in RecipeLibrary.seedRecipes() {
                context.insert(recipe)
            }
        }

        let rewardCount = (try? context.fetchCount(FetchDescriptor<Reward>())) ?? 0
        if rewardCount == 0 {
            for reward in RewardCatalog.starterRewards() {
                context.insert(reward)
            }
            for reward in RewardCatalog.milestoneRewards() {
                context.insert(reward)
            }
        }
        save()
    }

    // MARK: - Starting and ending runs

    @discardableResult
    func startRun(tier: ChallengeTier, profile: UserProfile) -> ChallengeRun {
        let previousAttempts = allRuns().count
        if let current = activeRun() {
            end(run: current, reason: .tierChanged)
        }

        let ruleSet = TierEngine.buildRules(tier: tier, profile: profile)
        let run = ChallengeRun(tier: tier, ruleSet: ruleSet, attemptNumber: previousAttempts + 1)
        context.insert(run)
        save()

        Task { await NotificationManager.shared.rescheduleAll(profile: profile, ruleSet: ruleSet) }
        return run
    }

    func end(run: ChallengeRun, reason: RunEndReason) {
        run.isActive = false
        run.endedAt = Date()
        run.endReason = reason
        save()
    }

    /// 75 Hard's restart. Kept honest — the old run is preserved, not deleted.
    @discardableResult
    func restart(run: ChallengeRun, profile: UserProfile, tier: ChallengeTier? = nil) -> ChallengeRun {
        end(run: run, reason: .restarted)
        return startRun(tier: tier ?? run.tier, profile: profile)
    }

    /// Regenerates the rules for an in-flight run after a profile change.
    func readaptRules(run: ChallengeRun, profile: UserProfile) {
        let ruleSet = TierEngine.buildRules(tier: run.tier, profile: profile)
        run.ruleSetData = ruleSet.encoded()
        save()
        Task { await NotificationManager.shared.rescheduleAll(profile: profile, ruleSet: ruleSet) }
    }

    // MARK: - Days

    /// Returns today's log, creating it and its task entries if needed.
    @discardableResult
    func ensureToday(for run: ChallengeRun) -> DayLog? {
        guard let dayNumber = run.currentDayNumber else { return nil }
        if let existing = run.day(number: dayNumber) {
            syncEntries(for: existing, run: run)
            return existing
        }

        let day = DayLog(dayNumber: dayNumber, date: Date())
        day.run = run
        context.insert(day)
        syncEntries(for: day, run: run)
        save()
        return day
    }

    /// Makes sure every rule in the run has a matching entry on the day, and
    /// that targets reflect today's scale factor.
    private func syncEntries(for day: DayLog, run: ChallengeRun) {
        let ruleSet = run.ruleSet
        for rule in ruleSet.rules {
            let target = DayScaler.scaledTarget(for: rule, scaleFactor: day.scaleFactor)
            if let entry = day.entry(for: rule.id) {
                if entry.target != target { entry.target = target }
            } else {
                let entry = TaskEntry(ruleID: rule.id, target: target)
                entry.day = day
                context.insert(entry)
            }
        }
    }

    // MARK: - Check-in

    func submitCheckIn(
        day: DayLog,
        run: ChallengeRun,
        profile: UserProfile,
        checkIn: DayScaler.CheckIn
    ) -> DayScaler.Outcome {
        let outcome = DayScaler.evaluate(checkIn, profile: profile)

        day.hasCheckedIn = true
        day.sleepHours = checkIn.sleepHours
        day.painScore = checkIn.painScore
        day.energyScore = checkIn.energyScore
        day.sorenessScore = checkIn.sorenessScore
        day.scaleFactor = outcome.scaleFactor
        day.scaleReason = outcome.reason

        syncEntries(for: day, run: run)
        save()
        return outcome
    }

    // MARK: - Logging progress

    func log(rule: TaskRule, amount: Double, on day: DayLog, run: ChallengeRun, profile: UserProfile) {
        guard let entry = day.entry(for: rule.id) else { return }
        let wasSatisfied = entry.isSatisfied
        entry.add(amount)

        if entry.isSatisfied && !wasSatisfied {
            Haptics.complete()
        } else {
            Haptics.tap()
        }

        settleIfComplete(day: day, run: run, profile: profile)
        save()
    }

    func toggle(rule: TaskRule, on day: DayLog, run: ChallengeRun, profile: UserProfile) {
        guard let entry = day.entry(for: rule.id) else { return }
        entry.toggleManualCompletion()
        if entry.isSatisfied { Haptics.complete() } else { Haptics.tap() }
        settleIfComplete(day: day, run: run, profile: profile)
        save()
    }

    func setPhoto(_ data: Data?, on day: DayLog, run: ChallengeRun, profile: UserProfile) {
        day.photoData = data
        if data != nil, let entry = day.entry(for: "photo"), !entry.isSatisfied {
            entry.toggleManualCompletion()
        }
        settleIfComplete(day: day, run: run, profile: profile)
        save()
    }

    func setReflection(_ text: String, on day: DayLog, run: ChallengeRun, profile: UserProfile) {
        day.reflection = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry = day.entry(for: "reflection") {
            let shouldBeComplete = !trimmed.isEmpty
            if entry.isManuallyComplete != shouldBeComplete {
                entry.toggleManualCompletion()
            }
        }
        settleIfComplete(day: day, run: run, profile: profile)
        save()
    }

    // MARK: - Day completion

    /// Awards XP and coins the first time a day becomes complete.
    private func settleIfComplete(day: DayLog, run: ChallengeRun, profile: UserProfile) {
        let ruleSet = run.ruleSet
        let complete = day.evaluateCompletion(against: ruleSet)

        guard complete, !day.isComplete else { return }

        let streakBefore = StreakEngine.summarise(run: run).current
        let award = XPEngine.award(day: day, ruleSet: ruleSet, streak: streakBefore, tier: run.tier)

        day.isComplete = true
        day.completedAt = Date()
        day.xpEarned = award.totalXP
        day.coinsEarned = award.coins

        run.xp += award.totalXP
        run.coins += award.coins
        if award.freezeTokenEarned { run.freezeTokens += 1 }

        let summaryAfter = StreakEngine.summarise(run: run)
        run.longestStreak = max(run.longestStreak, summaryAfter.longest)

        let achievements = grantAchievements(run: run, profile: profile)
        let achievementCoins = achievements.reduce(0) { $0 + $1.coinReward }
        run.coins += achievementCoins

        Haptics.celebrate()

        var message = "Day \(day.dayNumber) of \(run.totalDays) complete."
        if award.multiplier > 1 {
            message += " Streak multiplier ×\(String(format: "%.2f", award.multiplier))."
        }
        if day.scaleFactor < 1 {
            message += " You did it on a day your body voted against — that's the one that counts."
        }

        pendingCelebration = Celebration(
            title: run.isFinished ? "Seventy-five days. Done." : "Day complete",
            message: message,
            symbolName: run.isFinished ? "flag.checkered" : "checkmark.seal.fill",
            coins: award.coins + achievementCoins,
            achievements: achievements
        )

        if run.isFinished {
            end(run: run, reason: .completed)
        }
        save()
    }

    private func grantAchievements(run: ChallengeRun, profile: UserProfile) -> [Achievement] {
        let plannedMeals = (try? context.fetchCount(FetchDescriptor<MealPlanEntry>())) ?? 0
        let redemptions = (try? context.fetchCount(FetchDescriptor<Redemption>())) ?? 0

        let unlocked = AchievementEngine.newlyUnlocked(
            run: run,
            profile: profile,
            alreadyUnlocked: unlockedAchievementCodes(),
            redemptionCount: redemptions,
            plannedMealCount: plannedMeals
        )

        for achievement in unlocked {
            context.insert(AchievementRecord(code: achievement.code, runID: run.id))
        }
        return unlocked
    }

    // MARK: - Freezes, rest and misses

    /// Spends a freeze token to save a day. Not available on 75 Hard — that's
    /// the whole bargain of the tier.
    @discardableResult
    func useFreezeToken(on day: DayLog, run: ChallengeRun, profile: UserProfile) -> Bool {
        guard run.tier != .hard, run.freezeTokens > 0, !day.isComplete else { return false }

        run.freezeTokens -= 1
        day.usedFreezeToken = true
        day.isComplete = true
        day.completedAt = Date()
        day.isPlannedRestDay = true
        run.restDaysUsed += 1

        Haptics.complete()
        pendingCelebration = Celebration(
            title: "Day protected",
            message: "You've spent a freeze on day \(day.dayNumber). The streak holds. Rest is part of the plan, not a hole in it.",
            symbolName: "snowflake",
            coins: 0,
            achievements: []
        )
        save()
        return true
    }

    /// Days that ended incomplete and still need a decision from the user.
    func unresolvedMissedDays(for run: ChallengeRun) -> [DayLog] {
        let ruleSet = run.ruleSet
        return run.sortedDays.filter { $0.needsMissResolution(against: ruleSet) }
    }

    /// Records that the user has dealt with a missed day, so it stops prompting.
    func acknowledgeMiss(on day: DayLog) {
        day.missAcknowledged = true
        save()
    }

    // MARK: - Rewards

    @discardableResult
    func redeem(reward: Reward, run: ChallengeRun, note: String = "") -> Bool {
        guard !reward.isMilestone else { return false }
        guard run.coins >= reward.cost else { return false }

        run.coins -= reward.cost
        reward.timesRedeemed += 1
        context.insert(Redemption(
            rewardTitle: reward.title,
            cost: reward.cost,
            dayNumber: run.currentDayNumber ?? run.completedDayCount,
            note: note
        ))
        Haptics.celebrate()
        save()
        return true
    }

    func addReward(title: String, detail: String, cost: Int, category: RewardCategory) {
        let reward = Reward(title: title, detail: detail, cost: cost, category: category, isCustom: true)
        context.insert(reward)
        save()
    }

    // MARK: - Meals

    func planMeal(recipe: Recipe, on date: Date, slot: MealSlot, servings: Int = 1) {
        let entry = MealPlanEntry(date: date, slot: slot, recipe: recipe, servings: servings)
        context.insert(entry)
        save()
    }

    func clearPlan(from start: Date, days: Int = 7) {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .day, value: days, to: startDay) else { return }

        let descriptor = FetchDescriptor<MealPlanEntry>(
            predicate: #Predicate { $0.date >= startDay && $0.date < end }
        )
        for entry in (try? context.fetch(descriptor)) ?? [] {
            context.delete(entry)
        }
        save()
    }

    func generateWeekPlan(from start: Date, profile: UserProfile, tier: ChallengeTier) {
        clearPlan(from: start)
        let meals = MealPlanner.generateWeek(
            startingOn: Calendar.current.startOfDay(for: start),
            recipes: allRecipes(),
            profile: profile,
            tier: tier
        )
        for meal in meals {
            planMeal(recipe: meal.recipe, on: meal.date, slot: meal.slot, servings: meal.servings)
        }
    }

    func mealEntries(from start: Date, days: Int = 7) -> [MealPlanEntry] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .day, value: days, to: startDay) else { return [] }

        let descriptor = FetchDescriptor<MealPlanEntry>(
            predicate: #Predicate { $0.date >= startDay && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func rebuildShoppingList(weekStart: Date) {
        let startDay = Calendar.current.startOfDay(for: weekStart)

        let existing = FetchDescriptor<ShoppingItem>(
            predicate: #Predicate { $0.weekStart == startDay && $0.isManuallyAdded == false }
        )
        for item in (try? context.fetch(existing)) ?? [] {
            context.delete(item)
        }

        let entries = mealEntries(from: startDay)
        let items = MealPlanner.buildShoppingList(from: entries, recipes: allRecipes(), weekStart: startDay)
        for item in items {
            context.insert(item)
        }
        save()
    }

    func importRecipe(from urlString: String, slot: MealSlot) async throws -> Recipe {
        let draft = try await RecipeImporter.fetch(from: urlString)
        let recipe = RecipeImporter.makeRecipe(from: draft, slot: slot)
        context.insert(recipe)
        save()
        return recipe
    }

    // MARK: - Persistence

    func save() {
        do {
            try context.save()
        } catch {
            // SwiftData writes to a local store; a failure here means the disk
            // is full or the model is corrupt. Neither is silently recoverable,
            // but neither should crash a workout log either.
            print("SeventyFive: save failed — \(error.localizedDescription)")
        }
    }

    func deleteEverything() {
        try? context.delete(model: TaskEntry.self)
        try? context.delete(model: DayLog.self)
        try? context.delete(model: ChallengeRun.self)
        try? context.delete(model: MealPlanEntry.self)
        try? context.delete(model: ShoppingItem.self)
        try? context.delete(model: Redemption.self)
        try? context.delete(model: AchievementRecord.self)
        try? context.delete(model: Reward.self)
        try? context.delete(model: Recipe.self)
        try? context.delete(model: UserProfile.self)
        save()
    }
}
