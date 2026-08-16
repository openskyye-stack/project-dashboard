import SwiftUI
import SwiftData

@main
struct SeventyFiveApp: App {

    let container: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self,
            ChallengeRun.self,
            DayLog.self,
            TaskEntry.self,
            Recipe.self,
            MealPlanEntry.self,
            ShoppingItem.self,
            Reward.self,
            Redemption.self,
            AchievementRecord.self
        ])

        do {
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
        } catch {
            // A container that won't open means the on-disk store is unusable.
            // Falling back to memory keeps the app launchable so the user can at
            // least export or reset, rather than seeing a dead icon.
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
