import Foundation

/// A concrete way to actually do the workout, chosen to fit the person's
/// mobility, equipment and conditions.
struct ExerciseOption: Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var symbolName: String
    var isSeated: Bool
    var isLowImpact: Bool
    var isOutdoorCapable: Bool
    var requires: [EquipmentItem]
}

/// Translates a profile into safe, specific movement options.
///
/// The design rule here: never remove the task, change the shape of it. Someone
/// in a wheelchair still does a workout — it is a seated circuit, not a walk.
/// The challenge stays intact; only the modality moves.
enum MobilityAdaptation {

    // MARK: - Option catalogue

    static let allOptions: [ExerciseOption] = [
        ExerciseOption(
            id: "walk",
            title: "Walk",
            detail: "Steady pace where you can still hold a conversation.",
            symbolName: "figure.walk",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: true,
            requires: []
        ),
        ExerciseOption(
            id: "walk.intervals",
            title: "Walk with pick-ups",
            detail: "Two minutes easy, one minute brisk, repeated.",
            symbolName: "figure.walk.motion",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: true,
            requires: []
        ),
        ExerciseOption(
            id: "chair.circuit",
            title: "Seated strength circuit",
            detail: "Seated press, row, leg extension, knee lifts, twists. Three rounds.",
            symbolName: "chair.fill",
            isSeated: true,
            isLowImpact: true,
            isOutdoorCapable: true,
            requires: [.sturdyChair]
        ),
        ExerciseOption(
            id: "chair.cardio",
            title: "Seated cardio",
            detail: "Arm circles, seated marching, punches and reaches, kept continuous.",
            symbolName: "figure.seated.side",
            isSeated: true,
            isLowImpact: true,
            isOutdoorCapable: true,
            requires: [.sturdyChair]
        ),
        ExerciseOption(
            id: "band.strength",
            title: "Resistance band strength",
            detail: "Row, chest press, pull-apart, seated leg press. Two to three rounds.",
            symbolName: "figure.flexibility",
            isSeated: true,
            isLowImpact: true,
            isOutdoorCapable: false,
            requires: [.resistanceBands]
        ),
        ExerciseOption(
            id: "sit.to.stand",
            title: "Sit-to-stand sets",
            detail: "Stand from a chair without using your hands, sit slowly. The single best predictor of staying independent.",
            symbolName: "figure.stand",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: false,
            requires: [.sturdyChair]
        ),
        ExerciseOption(
            id: "balance.supported",
            title: "Supported balance work",
            detail: "Heel-to-toe stand, single-leg stand, weight shifts — one hand on a counter.",
            symbolName: "figure.stand.line.dotted.figure.stand",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: false,
            requires: []
        ),
        ExerciseOption(
            id: "pool",
            title: "Pool walking or swimming",
            detail: "Water takes the load off every joint. Ideal on sore days.",
            symbolName: "figure.pool.swim",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: true,
            requires: [.pool]
        ),
        ExerciseOption(
            id: "bike",
            title: "Stationary bike",
            detail: "Zero impact, easy to keep conversational.",
            symbolName: "bicycle",
            isSeated: true,
            isLowImpact: true,
            isOutdoorCapable: false,
            requires: [.treadmillOrBike]
        ),
        ExerciseOption(
            id: "dumbbell.full",
            title: "Dumbbell full body",
            detail: "Goblet squat, row, press, hinge, carry.",
            symbolName: "dumbbell.fill",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: false,
            requires: [.lightDumbbells]
        ),
        ExerciseOption(
            id: "bodyweight",
            title: "Bodyweight circuit",
            detail: "Squats, push-ups, lunges, planks. Three rounds.",
            symbolName: "figure.strengthtraining.functional",
            isSeated: false,
            isLowImpact: false,
            isOutdoorCapable: true,
            requires: []
        ),
        ExerciseOption(
            id: "mobility.flow",
            title: "Mobility flow",
            detail: "Ankles, hips, thoracic spine, shoulders. Slow and unhurried.",
            symbolName: "figure.cooldown",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: false,
            requires: []
        ),
        ExerciseOption(
            id: "chair.yoga",
            title: "Chair yoga",
            detail: "Seated sun salutation, spinal twists, gentle hamstring work.",
            symbolName: "figure.yoga",
            isSeated: true,
            isLowImpact: true,
            isOutdoorCapable: false,
            requires: [.sturdyChair]
        ),
        ExerciseOption(
            id: "garden",
            title: "Gardening or yard work",
            detail: "Counts when it's continuous and you're warm and slightly breathless.",
            symbolName: "leaf.fill",
            isSeated: false,
            isLowImpact: true,
            isOutdoorCapable: true,
            requires: []
        ),
        ExerciseOption(
            id: "porch.session",
            title: "Doorstep session",
            detail: "The whole workout done on a porch, balcony or just inside an open door. Outdoors without going anywhere.",
            symbolName: "door.left.hand.open",
            isSeated: true,
            isLowImpact: true,
            isOutdoorCapable: true,
            requires: []
        )
    ]

    // MARK: - Selection

    /// Options that are safe and possible for this person, best fit first.
    static func options(for profile: UserProfile, outdoorOnly: Bool = false) -> [ExerciseOption] {
        let owned = Set(profile.equipment)
        let mobility = profile.mobility
        let lowImpactOnly = profile.needsLowImpact

        return allOptions.filter { option in
            if outdoorOnly && !option.isOutdoorCapable { return false }
            if lowImpactOnly && !option.isLowImpact { return false }
            if mobility == .seated && !option.isSeated { return false }
            if mobility.requiresSeatedOptions && option.id == "bodyweight" { return false }
            // Balance work near a fall risk is fine, but only the supported version.
            if profile.isFallRisk && option.id == "walk.intervals" { return false }
            // Equipment gate: a chair is assumed available to everyone.
            let needed = option.requires.filter { $0 != .sturdyChair }
            return needed.allSatisfy { owned.contains($0) }
        }
        .sorted { lhs, rhs in
            score(lhs, for: profile) > score(rhs, for: profile)
        }
    }

    private static func score(_ option: ExerciseOption, for profile: UserProfile) -> Int {
        var score = 0
        if profile.mobility.requiresSeatedOptions && option.isSeated { score += 3 }
        if profile.needsLowImpact && option.isLowImpact { score += 2 }
        if profile.ageBand.needsBalanceWork && option.id.hasPrefix("balance") { score += 2 }
        if profile.ageBand.needsBalanceWork && option.id == "sit.to.stand" { score += 2 }
        if profile.equipment.contains(where: { option.requires.contains($0) }) { score += 1 }
        if option.requires.isEmpty { score += 1 }
        return score
    }

    /// How the outdoor requirement should be honoured for this person.
    /// 75 Hard insists one workout is outdoors "regardless of weather". For
    /// someone with a fall risk on an icy pavement, that rule is how people get
    /// hurt — so it becomes an outdoor *presence* requirement instead.
    static func outdoorPolicy(for profile: UserProfile) -> OutdoorPolicy {
        switch profile.outdoorAccess {
        case .unsafeOrUnavailable:
            return .indoorWithFreshAir
        case .limited:
            return profile.isFallRisk ? .doorstepOrSheltered : .outdoorWithConditions
        case .easy:
            if profile.isFallRisk { return .doorstepOrSheltered }
            return .fullyOutdoor
        }
    }

    /// Safety constraints to print on the workout card.
    static func safetyFlags(for profile: UserProfile) -> [String] {
        var flags: [String] = []

        if profile.needsIntensityCap {
            flags.append("Keep effort conversational — you should be able to speak a full sentence.")
        }
        if profile.isFallRisk {
            flags.append("Stay within reach of something solid. No balance work in open space.")
        }
        if profile.needsLowImpact {
            flags.append("No jumping, running or deep impact. Low-impact movement only.")
        }
        if !profile.mobility.allowsFloorWork {
            flags.append("Nothing that needs getting down to or up from the floor.")
        }
        if profile.considerations.contains(.osteoporosis) {
            flags.append("No loaded forward bends or twisting sit-ups.")
        }
        if profile.considerations.contains(.diabetes) {
            flags.append("Have fast-acting glucose within reach.")
        }
        if profile.considerations.contains(.asthmaOrCOPD) {
            flags.append("Reliever inhaler on you before you start.")
        }
        return flags
    }

    /// Universal stop signs, shown on every workout card regardless of profile.
    static let stopSigns: [String] = [
        "Chest pain, pressure or tightness",
        "Breathlessness out of proportion to the effort",
        "Dizziness, greying vision or feeling faint",
        "New or sharp joint pain, rather than muscle burn",
        "An irregular or racing heartbeat at rest"
    ]
}

enum OutdoorPolicy: String, Codable {
    case fullyOutdoor
    case outdoorWithConditions
    case doorstepOrSheltered
    case indoorWithFreshAir

    var title: String {
        switch self {
        case .fullyOutdoor: return "Outdoors, whatever the weather"
        case .outdoorWithConditions: return "Outdoors when it's safe underfoot"
        case .doorstepOrSheltered: return "Doorstep, balcony or sheltered ground"
        case .indoorWithFreshAir: return "Indoors, window open"
        }
    }

    var detail: String {
        switch self {
        case .fullyOutdoor:
            return "One session happens outside. Rain and cold are part of it."
        case .outdoorWithConditions:
            return "Outside is the default. Ice, storms or heat warnings move it under cover — that still counts."
        case .doorstepOrSheltered:
            return "Level, familiar ground only. A porch, balcony or covered path counts as outside."
        case .indoorWithFreshAir:
            return "Fresh air on your face for a few minutes counts. The workout itself stays indoors."
        }
    }
}
