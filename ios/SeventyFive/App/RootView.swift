import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<ChallengeRun> { $0.isActive }) private var activeRuns: [ChallengeRun]

    @State private var store: ChallengeStore?

    var body: some View {
        Group {
            if let store {
                if let profile = profiles.first, let run = activeRuns.first {
                    MainTabView(profile: profile, run: run)
                        .environment(store)
                } else if let profile = profiles.first {
                    // Profile exists but no active run — between attempts.
                    TierSelectionView(profile: profile, isOnboarding: false)
                        .environment(store)
                } else {
                    OnboardingFlow()
                        .environment(store)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if store == nil {
                let created = ChallengeStore(context: modelContext)
                created.seedIfNeeded()
                store = created
            }
        }
    }
}

struct MainTabView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let run: ChallengeRun

    @State private var selection: Tab = .today

    enum Tab: Hashable {
        case today, meals, rewards, progress, settings
    }

    var body: some View {
        @Bindable var bindableStore = store

        TabView(selection: $selection) {
            TodayView(profile: profile, run: run)
                .tabItem { Label("Today", systemImage: "checkmark.circle.fill") }
                .tag(Tab.today)

            MealsView(profile: profile, run: run)
                .tabItem { Label("Meals", systemImage: "fork.knife") }
                .tag(Tab.meals)

            RewardsView(profile: profile, run: run)
                .tabItem { Label("Rewards", systemImage: "gift.fill") }
                .tag(Tab.rewards)

            ProgressTabView(profile: profile, run: run)
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                .tag(Tab.progress)

            SettingsView(profile: profile, run: run)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.tierColor(run.tier))
        .sheet(item: $bindableStore.pendingCelebration) { celebration in
            CelebrationSheet(celebration: celebration)
        }
        .dynamicTypeSize(profile.wantsLargeText ? .accessibility1 ... .accessibility5 : .xSmall ... .accessibility5)
    }
}
