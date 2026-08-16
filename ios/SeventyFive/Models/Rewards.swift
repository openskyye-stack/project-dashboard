import Foundation
import SwiftData

/// Something the person actually wants, priced in Grit Coins.
///
/// The catalogue ships with suggestions, but a reward only works if it's yours —
/// so onboarding asks you to name three, and you can add more at any time.
@Model
final class Reward {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""
    var cost: Int = 50
    var categoryRaw: String = RewardCategory.treat.rawValue
    var symbolName: String = "gift.fill"
    var isCustom: Bool = false
    var isArchived: Bool = false
    var timesRedeemed: Int = 0
    var createdAt: Date = Date()

    /// Milestone rewards unlock at a day number rather than being bought.
    var unlocksAtDay: Int?

    init(
        title: String,
        detail: String,
        cost: Int,
        category: RewardCategory,
        symbolName: String? = nil,
        isCustom: Bool = false,
        unlocksAtDay: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.cost = cost
        self.categoryRaw = category.rawValue
        self.symbolName = symbolName ?? category.symbol
        self.isCustom = isCustom
        self.unlocksAtDay = unlocksAtDay
    }

    var category: RewardCategory {
        get { RewardCategory(rawValue: categoryRaw) ?? .treat }
        set { categoryRaw = newValue.rawValue }
    }

    var isMilestone: Bool { unlocksAtDay != nil }
}

@Model
final class Redemption {
    var id: UUID = UUID()
    var rewardTitle: String = ""
    var cost: Int = 0
    var date: Date = Date()
    var dayNumber: Int = 0
    var note: String = ""

    init(rewardTitle: String, cost: Int, dayNumber: Int, note: String = "") {
        self.id = UUID()
        self.rewardTitle = rewardTitle
        self.cost = cost
        self.dayNumber = dayNumber
        self.note = note
        self.date = Date()
    }
}

/// An earned badge. The catalogue lives in `AchievementCatalog`; only unlocks
/// are persisted.
@Model
final class AchievementRecord {
    var code: String = ""
    var unlockedAt: Date = Date()
    var runID: UUID?
    var isSeen: Bool = false

    init(code: String, runID: UUID?) {
        self.code = code
        self.runID = runID
        self.unlockedAt = Date()
    }
}

/// Static definition of a badge.
struct Achievement: Identifiable, Hashable {
    var id: String { code }
    var code: String
    var title: String
    var detail: String
    var symbolName: String
    var coinReward: Int
    var isSecret: Bool

    init(
        code: String,
        title: String,
        detail: String,
        symbolName: String,
        coinReward: Int = 25,
        isSecret: Bool = false
    ) {
        self.code = code
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.coinReward = coinReward
        self.isSecret = isSecret
    }
}
