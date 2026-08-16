import Foundation

/// A single daily requirement, already adapted to the person who will do it.
///
/// Rules are generated once when a run starts (`TierEngine.buildRules`) and
/// frozen into the run, so that changing your profile mid-challenge doesn't
/// silently rewrite history. Re-adapting is an explicit action in Settings.
struct TaskRule: Codable, Identifiable, Hashable {
    var id: String
    var kind: TaskKind
    var title: String
    var detail: String
    var target: Double
    var unit: MeasureUnit
    var isRequired: Bool
    var allowsPartialCredit: Bool
    var xpValue: Int
    var iconName: String

    /// How many separate chunks this may be broken into and still count.
    /// Three fifteen-minute walks beat one forty-five-minute walk that never happens.
    var maxSplits: Int

    /// Plain-language notes on what was changed for this person and why.
    /// Shown in the rule detail sheet so the adaptation is never a black box.
    var adaptations: [String]

    /// Hard safety constraints surfaced on the task card itself.
    var safetyFlags: [String]

    init(
        id: String,
        kind: TaskKind,
        title: String,
        detail: String,
        target: Double,
        unit: MeasureUnit,
        isRequired: Bool = true,
        allowsPartialCredit: Bool = true,
        xpValue: Int = 20,
        iconName: String? = nil,
        maxSplits: Int = 1,
        adaptations: [String] = [],
        safetyFlags: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.target = target
        self.unit = unit
        self.isRequired = isRequired
        self.allowsPartialCredit = allowsPartialCredit
        self.xpValue = xpValue
        self.iconName = iconName ?? kind.defaultIcon
        self.maxSplits = maxSplits
        self.adaptations = adaptations
        self.safetyFlags = safetyFlags
    }

    var targetDescription: String { unit.format(target) }

    var isBinary: Bool { unit == .yesNo }

    /// Suggested size of one chunk when the rule may be split.
    var chunkDescription: String? {
        guard maxSplits > 1, unit == .minutes else { return nil }
        let chunk = Int((target / Double(maxSplits)).rounded())
        return "Counts as \(maxSplits) × \(chunk) min"
    }
}

/// Container so a `[TaskRule]` can be versioned inside the stored blob.
struct RuleSet: Codable {
    var version: Int
    var tier: ChallengeTier
    var generatedAt: Date
    var rules: [TaskRule]

    /// Notes about the whole plan rather than one rule.
    var globalNotes: [String]

    static let currentVersion = 1

    init(tier: ChallengeTier, rules: [TaskRule], globalNotes: [String] = [], generatedAt: Date = Date()) {
        self.version = RuleSet.currentVersion
        self.tier = tier
        self.rules = rules
        self.globalNotes = globalNotes
        self.generatedAt = generatedAt
    }

    var requiredRules: [TaskRule] { rules.filter(\.isRequired) }
    var optionalRules: [TaskRule] { rules.filter { !$0.isRequired } }
    var totalDailyXP: Int { rules.reduce(0) { $0 + $1.xpValue } }

    func rule(id: String) -> TaskRule? { rules.first { $0.id == id } }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> RuleSet? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(RuleSet.self, from: data)
    }
}
