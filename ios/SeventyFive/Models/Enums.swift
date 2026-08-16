import Foundation

// MARK: - Challenge tier

/// The three community variants of the 75-day challenge.
/// All three run for 75 days; they differ in how demanding the daily rules are
/// and in what happens when a day is missed.
enum ChallengeTier: String, Codable, CaseIterable, Identifiable {
    case soft
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soft: return "75 Soft"
        case .medium: return "75 Medium"
        case .hard: return "75 Hard"
        }
    }

    var tagline: String {
        switch self {
        case .soft: return "Build the habit. Nothing resets."
        case .medium: return "Real demands, humane rules."
        case .hard: return "No compromise. Miss a task, start over."
        }
    }

    var blurb: String {
        switch self {
        case .soft:
            return "One workout a day, sensible hydration, whole foods, ten pages. Miss a day and you simply pick the streak back up tomorrow."
        case .medium:
            return "A full workout plus a daily walk, a firmer hydration target, one planned treat meal a week. You get grace days instead of a hard reset."
        case .hard:
            return "Two workouts a day, one of them outdoors, no treat meals, no alcohol, and a photo every single day. Miss any required task and the run restarts at day one."
        }
    }

    /// Ordered from gentlest to hardest, used for recommendations and step-downs.
    var intensityRank: Int {
        switch self {
        case .soft: return 0
        case .medium: return 1
        case .hard: return 2
        }
    }

    var gentler: ChallengeTier? {
        switch self {
        case .hard: return .medium
        case .medium: return .soft
        case .soft: return nil
        }
    }

    /// What happens when a required task is left undone at the end of a day.
    var missPolicy: MissPolicy {
        switch self {
        case .hard: return .restart
        case .medium: return .graceDays(perBlock: 1, blockLength: 25)
        case .soft: return .streakBreakOnly
        }
    }

    var accentSymbol: String {
        switch self {
        case .soft: return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard: return "bolt.fill"
        }
    }
}

enum MissPolicy: Equatable {
    /// Classic 75 Hard: the run resets to day one.
    case restart
    /// A limited number of forgiven days per block of days.
    case graceDays(perBlock: Int, blockLength: Int)
    /// The streak counter breaks but the run continues.
    case streakBreakOnly
}

// MARK: - Daily tasks

enum TaskKind: String, Codable, CaseIterable {
    case workout
    case outdoorWorkout
    case movementSnack
    case hydration
    case nutrition
    case reading
    case progressPhoto
    case mobilityWork
    case balanceWork
    case sleep
    case reflection

    var defaultIcon: String {
        switch self {
        case .workout: return "figure.strengthtraining.functional"
        case .outdoorWorkout: return "sun.max.fill"
        case .movementSnack: return "figure.walk"
        case .hydration: return "drop.fill"
        case .nutrition: return "fork.knife"
        case .reading: return "book.fill"
        case .progressPhoto: return "camera.fill"
        case .mobilityWork: return "figure.cooldown"
        case .balanceWork: return "figure.stand"
        case .sleep: return "bed.double.fill"
        case .reflection: return "text.book.closed.fill"
        }
    }
}

enum MeasureUnit: String, Codable {
    case minutes
    case milliliters
    case pages
    case sessions
    case count
    case yesNo

    func format(_ value: Double) -> String {
        switch self {
        case .minutes:
            return "\(Int(value.rounded())) min"
        case .milliliters:
            return HydrationFormatter.short(milliliters: value)
        case .pages:
            return "\(Int(value.rounded())) pages"
        case .sessions:
            let n = Int(value.rounded())
            return n == 1 ? "1 session" : "\(n) sessions"
        case .count:
            return "\(Int(value.rounded()))"
        case .yesNo:
            return value >= 1 ? "Done" : "Not yet"
        }
    }

    /// Sensible increment for the plus/minus stepper on a task card.
    var step: Double {
        switch self {
        case .minutes: return 5
        case .milliliters: return 250
        case .pages: return 1
        case .sessions, .count: return 1
        case .yesNo: return 1
        }
    }
}

// MARK: - Person and body

enum MobilityLevel: String, Codable, CaseIterable, Identifiable {
    case unrestricted
    case mildLimitation
    case moderateLimitation
    case usesWalkingAid
    case seated

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unrestricted: return "No real limits"
        case .mildLimitation: return "Some stiffness or slower going"
        case .moderateLimitation: return "Standing and stairs are hard"
        case .usesWalkingAid: return "I use a cane, walker or rollator"
        case .seated: return "I exercise seated or use a wheelchair"
        }
    }

    var detail: String {
        switch self {
        case .unrestricted:
            return "You can walk, climb stairs and get up from the floor without help."
        case .mildLimitation:
            return "You get around fine but joints complain, or you need a moment to get going."
        case .moderateLimitation:
            return "Long standing, stairs or getting off the floor is genuinely difficult."
        case .usesWalkingAid:
            return "You rely on a device for walking distance or stability."
        case .seated:
            return "Your workouts happen from a chair or wheelchair."
        }
    }

    /// Whether floor-based exercises should ever be suggested.
    var allowsFloorWork: Bool {
        switch self {
        case .unrestricted, .mildLimitation: return true
        case .moderateLimitation, .usesWalkingAid, .seated: return false
        }
    }

    var requiresSeatedOptions: Bool {
        switch self {
        case .seated, .usesWalkingAid, .moderateLimitation: return true
        case .unrestricted, .mildLimitation: return false
        }
    }
}

enum PainLevel: String, Codable, CaseIterable, Identifiable {
    case none
    case mild
    case moderate
    case severe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .mild: return "Mild — noticeable, not limiting"
        case .moderate: return "Moderate — it changes what I do"
        case .severe: return "Severe — it stops me"
        }
    }

    /// How much of a nominal workout duration is realistic to ask for.
    var durationMultiplier: Double {
        switch self {
        case .none: return 1.0
        case .mild: return 0.9
        case .moderate: return 0.7
        case .severe: return 0.5
        }
    }
}

/// Conditions that meaningfully change what the app should ask of someone.
/// This is deliberately a short, high-signal list rather than a medical history.
enum HealthConsideration: String, Codable, CaseIterable, Identifiable {
    case heartCondition
    case highBloodPressure
    case diabetes
    case asthmaOrCOPD
    case arthritis
    case osteoporosis
    case backOrDiscIssue
    case jointReplacement
    case kidneyDisease
    case heartFailure
    case fluidRestriction
    case dizzinessOrFainting
    case neuropathy
    case recentSurgery
    case pregnancy
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heartCondition: return "Heart condition"
        case .highBloodPressure: return "High blood pressure"
        case .diabetes: return "Diabetes"
        case .asthmaOrCOPD: return "Asthma or COPD"
        case .arthritis: return "Arthritis"
        case .osteoporosis: return "Osteoporosis or low bone density"
        case .backOrDiscIssue: return "Back or disc problem"
        case .jointReplacement: return "Joint replacement"
        case .kidneyDisease: return "Kidney disease"
        case .heartFailure: return "Heart failure"
        case .fluidRestriction: return "I've been told to limit fluids"
        case .dizzinessOrFainting: return "Dizziness or fainting spells"
        case .neuropathy: return "Numbness in feet or hands"
        case .recentSurgery: return "Surgery in the last 3 months"
        case .pregnancy: return "Pregnant or recently postpartum"
        case .none: return "None of these"
        }
    }

    /// Conditions where a fixed high fluid target can be actively dangerous.
    var capsHydration: Bool {
        switch self {
        case .kidneyDisease, .heartFailure, .fluidRestriction: return true
        default: return false
        }
    }

    /// Conditions where impact loading should be avoided or minimised.
    var favoursLowImpact: Bool {
        switch self {
        case .arthritis, .osteoporosis, .backOrDiscIssue, .jointReplacement,
             .neuropathy, .recentSurgery, .pregnancy:
            return true
        default:
            return false
        }
    }

    /// Conditions where intensity should be capped to a conversational effort.
    var capsIntensity: Bool {
        switch self {
        case .heartCondition, .highBloodPressure, .heartFailure, .asthmaOrCOPD,
             .dizzinessOrFainting, .recentSurgery, .pregnancy:
            return true
        default:
            return false
        }
    }

    /// Conditions that make unsupervised outdoor sessions on uneven ground risky.
    var favoursSupervisedOrIndoor: Bool {
        switch self {
        case .dizzinessOrFainting, .neuropathy, .osteoporosis, .recentSurgery:
            return true
        default:
            return false
        }
    }

    var safetyNote: String? {
        switch self {
        case .kidneyDisease, .heartFailure, .fluidRestriction:
            return "Your fluid target is capped and needs to come from your clinician, not from a challenge rule."
        case .diabetes:
            return "Carry fast-acting glucose and check levels before and after longer sessions."
        case .osteoporosis:
            return "No spinal flexion under load, no twisting crunches, and balance work stays next to a support."
        case .dizzinessOrFainting:
            return "Change position slowly and keep a hand on something stable for balance work."
        case .neuropathy:
            return "Check your feet daily and choose stable surfaces over uneven ground."
        case .heartCondition, .highBloodPressure:
            return "Effort stays conversational. Stop for chest pressure, unusual breathlessness or palpitations."
        case .asthmaOrCOPD:
            return "Keep your reliever inhaler with you and warm up longer in cold air."
        case .recentSurgery:
            return "Stay inside whatever limits your surgeon gave you — this app does not override them."
        case .pregnancy:
            return "Avoid lying flat on your back after the first trimester and skip anything with a fall risk."
        case .backOrDiscIssue:
            return "Hinge from the hips, avoid loaded rounding of the lower back."
        case .jointReplacement:
            return "Respect the range-of-motion limits from your surgeon, especially deep hip flexion."
        case .arthritis:
            return "Sore-but-settling within an hour is fine. Sharp or lingering joint pain is not."
        case .none:
            return nil
        }
    }
}

enum EquipmentItem: String, Codable, CaseIterable, Identifiable {
    case none
    case sturdyChair
    case resistanceBands
    case lightDumbbells
    case heavyDumbbells
    case kettlebell
    case treadmillOrBike
    case pool
    case gymMembership
    case yogaMat
    case pullUpBar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Nothing yet"
        case .sturdyChair: return "A sturdy chair"
        case .resistanceBands: return "Resistance bands"
        case .lightDumbbells: return "Light dumbbells"
        case .heavyDumbbells: return "Heavier dumbbells"
        case .kettlebell: return "Kettlebell"
        case .treadmillOrBike: return "Treadmill or stationary bike"
        case .pool: return "Pool access"
        case .gymMembership: return "Gym membership"
        case .yogaMat: return "Yoga mat"
        case .pullUpBar: return "Pull-up bar"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "circle.slash"
        case .sturdyChair: return "chair.fill"
        case .resistanceBands: return "figure.flexibility"
        case .lightDumbbells, .heavyDumbbells: return "dumbbell.fill"
        case .kettlebell: return "figure.strengthtraining.traditional"
        case .treadmillOrBike: return "bicycle"
        case .pool: return "figure.pool.swim"
        case .gymMembership: return "building.2.fill"
        case .yogaMat: return "figure.yoga"
        case .pullUpBar: return "figure.play"
        }
    }
}

enum OutdoorAccess: String, Codable, CaseIterable, Identifiable {
    case easy
    case limited
    case unsafeOrUnavailable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy — I can get outside daily"
        case .limited: return "Limited — weather or transport gets in the way"
        case .unsafeOrUnavailable: return "Not realistic for me"
        }
    }
}

enum DietaryPreference: String, Codable, CaseIterable, Identifiable {
    case none
    case vegetarian
    case vegan
    case pescatarian
    case glutenFree
    case dairyFree
    case lowSodium
    case lowCarb
    case softTexture
    case nutFree
    case halal
    case kosher

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No restrictions"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .glutenFree: return "Gluten free"
        case .dairyFree: return "Dairy free"
        case .lowSodium: return "Low sodium"
        case .lowCarb: return "Lower carb"
        case .softTexture: return "Easy to chew"
        case .nutFree: return "Nut free"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        }
    }
}

enum ReadingFormat: String, Codable, CaseIterable, Identifiable {
    case print
    case ebook
    case audiobook

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .print: return "Paper book"
        case .ebook: return "E-reader"
        case .audiobook: return "Audiobook"
        }
    }
}

// MARK: - Meals

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
}

enum GroceryAisle: String, Codable, CaseIterable, Identifiable {
    case produce
    case meatAndFish
    case dairyAndEggs
    case pantry
    case grains
    case frozen
    case bakery
    case spices
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .produce: return "Produce"
        case .meatAndFish: return "Meat & fish"
        case .dairyAndEggs: return "Dairy & eggs"
        case .pantry: return "Pantry"
        case .grains: return "Grains & bread"
        case .frozen: return "Frozen"
        case .bakery: return "Bakery"
        case .spices: return "Herbs & spices"
        case .other: return "Other"
        }
    }

    /// Rough order you'd walk a supermarket in, so the list sorts usefully.
    var walkOrder: Int {
        switch self {
        case .produce: return 0
        case .bakery: return 1
        case .meatAndFish: return 2
        case .dairyAndEggs: return 3
        case .grains: return 4
        case .pantry: return 5
        case .spices: return 6
        case .frozen: return 7
        case .other: return 8
        }
    }
}

// MARK: - Rewards

enum RewardCategory: String, Codable, CaseIterable, Identifiable {
    case rest
    case treat
    case experience
    case gear
    case social
    case milestone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rest: return "Rest & recovery"
        case .treat: return "Small treat"
        case .experience: return "Experience"
        case .gear: return "Gear"
        case .social: return "People"
        case .milestone: return "Milestone"
        }
    }

    var symbol: String {
        switch self {
        case .rest: return "bed.double.fill"
        case .treat: return "gift.fill"
        case .experience: return "ticket.fill"
        case .gear: return "bag.fill"
        case .social: return "person.2.fill"
        case .milestone: return "flag.checkered"
        }
    }
}

enum RunEndReason: String, Codable {
    case completed
    case restarted
    case abandoned
    case tierChanged
}
