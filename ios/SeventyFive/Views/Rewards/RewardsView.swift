import SwiftUI
import SwiftData

struct RewardsView: View {
    @Environment(ChallengeStore.self) private var store
    @Query(sort: \Reward.cost) private var rewards: [Reward]
    @Query(sort: \Redemption.date, order: .reverse) private var redemptions: [Redemption]
    @Query private var achievementRecords: [AchievementRecord]

    let profile: UserProfile
    let run: ChallengeRun

    @State private var showAddReward = false
    @State private var rewardToRedeem: Reward?

    private var shopRewards: [Reward] {
        rewards.filter { !$0.isArchived && !$0.isMilestone }
    }

    private var milestones: [Reward] {
        rewards.filter { $0.isMilestone }.sorted { ($0.unlocksAtDay ?? 0) < ($1.unlocksAtDay ?? 0) }
    }

    private var unlockedCodes: Set<String> { Set(achievementRecords.map(\.code)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    milestonesCard
                    shopSection
                    achievementsSection

                    if !redemptions.isEmpty {
                        historySection
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddReward = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a reward")
                }
            }
            .sheet(isPresented: $showAddReward) {
                AddRewardSheet()
            }
            .alert(
                "Redeem this?",
                isPresented: Binding(
                    get: { rewardToRedeem != nil },
                    set: { if !$0 { rewardToRedeem = nil } }
                ),
                presenting: rewardToRedeem
            ) { reward in
                Button("Redeem") { store.redeem(reward: reward, run: run) }
                Button("Not yet", role: .cancel) {}
            } message: { reward in
                Text("\(reward.title) costs \(reward.cost) coins. You'll have \(max(0, run.coins - reward.cost)) left.\n\nClaim it today — a reward you keep postponing stops working.")
            }
        }
    }

    // MARK: - Sections

    private var balanceCard: some View {
        let level = XPEngine.level(for: run.xp)
        return VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.coinColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(run.coins)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Grit Coins")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("Lv \(level.index)", systemImage: level.symbol)
                        .font(.headline)
                        .foregroundStyle(.purple)
                    Text(level.title)
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
            }

            Text("Ten coins a completed day, fifteen more every seventh day, plus two for finishing a day your body voted against.")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card(tint: Theme.coinColor)
    }

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Milestones",
                subtitle: "Unlocked by reaching the day, not by spending.",
                systemImage: "flag.checkered"
            )
            ForEach(milestones) { reward in
                let day = reward.unlocksAtDay ?? 0
                let isUnlocked = run.completedDayCount >= day
                HStack(spacing: 12) {
                    Image(systemName: isUnlocked ? reward.symbolName : "lock.fill")
                        .font(.title3)
                        .foregroundStyle(isUnlocked ? Theme.coinColor : Theme.subtle)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reward.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(isUnlocked ? Theme.ink : Theme.subtle)
                        Text(reward.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.subtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text("Day \(day)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isUnlocked ? Theme.success : Theme.subtle)
                }
                .frame(minHeight: 44)
            }
        }
        .card()
    }

    private var shopSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Spend your coins", subtitle: "Tap anything you can afford.", systemImage: "bag.fill")

            if shopRewards.isEmpty {
                Text("No rewards yet. Add something you actually want.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
            }

            ForEach(shopRewards) { reward in
                let affordable = run.coins >= reward.cost
                Button {
                    guard affordable else { return }
                    rewardToRedeem = reward
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: reward.symbolName)
                            .font(.title3)
                            .foregroundStyle(affordable ? Theme.coinColor : Theme.subtle)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reward.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            if !reward.detail.isEmpty {
                                Text(reward.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.subtle)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if reward.timesRedeemed > 0 {
                                Text("Claimed \(reward.timesRedeemed)×")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.success)
                            }
                        }
                        Spacer(minLength: 0)
                        VStack(spacing: 2) {
                            Text("\(reward.cost)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(affordable ? Theme.coinColor : Theme.subtle)
                            Image(systemName: "circle.hexagongrid.fill")
                                .font(.caption2)
                                .foregroundStyle(affordable ? Theme.coinColor : Theme.subtle)
                        }
                    }
                    .frame(minHeight: Theme.minimumTapTarget)
                    .opacity(affordable ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!affordable)
            }
        }
        .card()
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Badges",
                subtitle: "\(unlockedCodes.count) of \(AchievementCatalog.all.count) earned",
                systemImage: "rosette"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                ForEach(AchievementCatalog.all) { achievement in
                    let isUnlocked = unlockedCodes.contains(achievement.code)
                    VStack(spacing: 6) {
                        Image(systemName: isUnlocked ? achievement.symbolName : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(isUnlocked ? Theme.coinColor : Theme.subtle)
                        Text(achievement.title)
                            .font(.caption2.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(isUnlocked ? Theme.ink : Theme.subtle)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isUnlocked ? Theme.coinColor.opacity(0.12) : Color(.tertiarySystemBackground))
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isUnlocked
                        ? "\(achievement.title), earned. \(achievement.detail)"
                        : "\(achievement.title), locked.")
                }
            }
        }
        .card()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Claimed", systemImage: "clock.arrow.circlepath")
            ForEach(redemptions.prefix(10)) { redemption in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(redemption.rewardTitle).font(.callout.weight(.medium))
                        Text("Day \(redemption.dayNumber) · \(redemption.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(Theme.subtle)
                    }
                    Spacer()
                    Text("−\(redemption.cost)")
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.subtle)
                }
                .frame(minHeight: 40)
            }
        }
        .card()
    }
}

struct AddRewardSheet: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var cost: Double = 100
    @State private var category: RewardCategory = .treat

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is it?", text: $title)
                    TextField("Any detail (optional)", text: $detail)
                } header: {
                    Text("The reward")
                } footer: {
                    Text("Be specific. \"A massage on the 14th\" pulls harder than \"self care\".")
                }

                Section("Cost") {
                    LabelledStepper(value: $cost, range: 10...1000, step: 10, format: { "\(Int($0)) coins" })
                    Text("Roughly \(Int(cost / 10)) completed days.")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }

                Section("Kind") {
                    Picker("Category", selection: $category) {
                        ForEach(RewardCategory.allCases.filter { $0 != .milestone }) { option in
                            Label(option.displayName, systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("New reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.addReward(
                            title: title.trimmingCharacters(in: .whitespaces),
                            detail: detail.trimmingCharacters(in: .whitespaces),
                            cost: Int(cost),
                            category: category
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
