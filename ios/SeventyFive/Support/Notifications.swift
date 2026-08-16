import Foundation
import UserNotifications

/// Local notifications only — nothing leaves the device.
///
/// The scheduling deliberately front-loads hydration reminders and stops two
/// hours before wind-down, and it never nags after a task is already done.
@MainActor
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    enum Category: String {
        case morningCheckIn = "morning.checkin"
        case hydration = "hydration"
        case eveningSweep = "evening.sweep"
        case mealPrep = "meal.prep"
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Rebuilds the whole schedule. Called after onboarding and whenever the
    /// profile or rule set changes.
    func rescheduleAll(profile: UserProfile, ruleSet: RuleSet) async {
        cancelAll()

        await scheduleMorningCheckIn(hour: profile.preferredStartHour, name: profile.displayName)

        if let hydration = ruleSet.rule(id: "hydration") {
            let glasses = HydrationFormatter.glasses(milliliters: hydration.target)
            let hours = HydrationCalculator.reminderHours(for: profile, glassCount: glasses)
            await scheduleHydration(hours: hours, glassSize: 250)
        }

        await scheduleEveningSweep(hour: max(18, profile.preferredWindDownHour - 2))
        await scheduleWeeklyMealPrep(weekday: 1, hour: 10) // Sunday
    }

    private func scheduleMorningCheckIn(hour: Int, name: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Morning, \(name)"
        content.body = "Thirty seconds: how did you sleep, and how's the pain today? Today's plan adjusts to your answer."
        content.sound = .default
        content.categoryIdentifier = Category.morningCheckIn.rawValue

        await add(id: "checkin.daily", content: content, hour: hour, minute: 0)
    }

    private func scheduleHydration(hours: [Int], glassSize: Double) async {
        for (index, hour) in hours.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Water"
            content.body = index == 0
                ? "First glass of the day. Steady beats catching up at midnight."
                : "Time for another glass."
            content.sound = .default
            content.categoryIdentifier = Category.hydration.rawValue

            await add(id: "hydration.\(index)", content: content, hour: hour, minute: 0)
        }
    }

    private func scheduleEveningSweep(hour: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Anything left?"
        content.body = "Check what's still open while there's time to do something about it."
        content.sound = .default
        content.categoryIdentifier = Category.eveningSweep.rawValue

        await add(id: "evening.sweep", content: content, hour: hour, minute: 30)
    }

    private func scheduleWeeklyMealPrep(weekday: Int, hour: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Prep session"
        content.body = "Two hours today buys you a week of not deciding what to eat."
        content.sound = .default
        content.categoryIdentifier = Category.mealPrep.rawValue

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: "meal.prep.weekly",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    private func add(id: String, content: UNMutableNotificationContent, hour: Int, minute: Int) async {
        var components = DateComponents()
        components.hour = max(0, min(23, hour))
        components.minute = max(0, min(59, minute))

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    /// One-off nudge, used for milestone celebrations.
    func fireImmediate(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }
}
