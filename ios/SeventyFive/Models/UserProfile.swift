import Foundation
import SwiftData

/// Everything the onboarding interview learns about the person.
///
/// SwiftData stores enums as their raw strings here on purpose: it keeps the
/// store readable, migration-friendly, and lets us add cases without a
/// destructive schema change.
@Model
final class UserProfile {
    var name: String = ""
    var birthYear: Int = 1980
    var weightKg: Double = 75
    var heightCm: Double = 170

    var mobilityRaw: String = MobilityLevel.unrestricted.rawValue
    var jointPainRaw: String = PainLevel.none.rawValue

    /// 1 (very unsteady) to 5 (rock solid). Drives balance work and fall-risk logic.
    var balanceConfidence: Int = 4
    var hasFallenInLastYear: Bool = false

    var considerationsRaw: [String] = []
    var equipmentRaw: [String] = []
    var dietaryRaw: [String] = []

    var outdoorAccessRaw: String = OutdoorAccess.easy.rawValue
    var readingFormatRaw: String = ReadingFormat.print.rawValue

    /// Realistic minutes per day, which caps what the tier is allowed to ask for.
    var availableMinutesPerDay: Int = 90
    /// Minutes the person can stand or walk continuously before needing to sit.
    var continuousStandingMinutes: Int = 30

    /// Preferred hour of day (0-23) for the first reminder.
    var preferredStartHour: Int = 7
    var preferredWindDownHour: Int = 21

    var clinicianCleared: Bool = false
    var wantsLargeText: Bool = false
    var wantsReducedMotion: Bool = false
    var wantsVoiceLogging: Bool = false

    /// Motivation captured at onboarding and replayed on hard days.
    var whyStatement: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}

    // MARK: - Typed accessors

    var mobility: MobilityLevel {
        get { MobilityLevel(rawValue: mobilityRaw) ?? .unrestricted }
        set { mobilityRaw = newValue.rawValue }
    }

    var jointPain: PainLevel {
        get { PainLevel(rawValue: jointPainRaw) ?? .none }
        set { jointPainRaw = newValue.rawValue }
    }

    var considerations: [HealthConsideration] {
        get { considerationsRaw.compactMap(HealthConsideration.init(rawValue:)) }
        set { considerationsRaw = newValue.map(\.rawValue) }
    }

    var equipment: [EquipmentItem] {
        get { equipmentRaw.compactMap(EquipmentItem.init(rawValue:)) }
        set { equipmentRaw = newValue.map(\.rawValue) }
    }

    var dietary: [DietaryPreference] {
        get { dietaryRaw.compactMap(DietaryPreference.init(rawValue:)) }
        set { dietaryRaw = newValue.map(\.rawValue) }
    }

    var outdoorAccess: OutdoorAccess {
        get { OutdoorAccess(rawValue: outdoorAccessRaw) ?? .easy }
        set { outdoorAccessRaw = newValue.rawValue }
    }

    var readingFormat: ReadingFormat {
        get { ReadingFormat(rawValue: readingFormatRaw) ?? .print }
        set { readingFormatRaw = newValue.rawValue }
    }

    // MARK: - Derived

    var age: Int {
        let year = Calendar.current.component(.year, from: Date())
        return max(0, year - birthYear)
    }

    /// Broad age band. Used for duration floors, heat guidance and protein targets —
    /// never to tell someone they're too old for something.
    var ageBand: AgeBand {
        switch age {
        case ..<40: return .under40
        case 40..<55: return .fortyToFiftyFour
        case 55..<70: return .fiftyFiveToSixtyNine
        case 70..<80: return .seventyToSeventyNine
        default: return .eightyPlus
        }
    }

    var bmi: Double {
        guard heightCm > 0 else { return 0 }
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    var hasHydrationCap: Bool {
        considerations.contains { $0.capsHydration }
    }

    var needsLowImpact: Bool {
        considerations.contains { $0.favoursLowImpact } || jointPain == .moderate || jointPain == .severe
    }

    var needsIntensityCap: Bool {
        considerations.contains { $0.capsIntensity }
    }

    /// True when solo sessions on uneven outdoor ground are a genuine fall risk.
    var isFallRisk: Bool {
        if hasFallenInLastYear { return true }
        if balanceConfidence <= 2 { return true }
        if mobility == .usesWalkingAid || mobility == .seated { return true }
        return considerations.contains { $0.favoursSupervisedOrIndoor }
    }

    /// A clinician conversation is the responsible default for these people.
    var shouldPromptClinicianCheck: Bool {
        if clinicianCleared { return false }
        if age >= 65 { return true }
        if !considerations.filter({ $0 != .none }).isEmpty { return true }
        if mobility != .unrestricted { return true }
        return false
    }

    var safetyNotes: [String] {
        considerations.compactMap(\.safetyNote)
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Friend" : name
    }
}

enum AgeBand: String, Codable, CaseIterable {
    case under40
    case fortyToFiftyFour
    case fiftyFiveToSixtyNine
    case seventyToSeventyNine
    case eightyPlus

    var displayName: String {
        switch self {
        case .under40: return "Under 40"
        case .fortyToFiftyFour: return "40–54"
        case .fiftyFiveToSixtyNine: return "55–69"
        case .seventyToSeventyNine: return "70–79"
        case .eightyPlus: return "80+"
        }
    }

    /// Multiplier applied to nominal workout duration before other adjustments.
    var durationMultiplier: Double {
        switch self {
        case .under40: return 1.0
        case .fortyToFiftyFour: return 1.0
        case .fiftyFiveToSixtyNine: return 0.9
        case .seventyToSeventyNine: return 0.75
        case .eightyPlus: return 0.6
        }
    }

    /// Millilitres of fluid per kilogram of body weight, before condition caps.
    /// Older kidneys concentrate urine less well, but thirst also blunts with age,
    /// so the target drops modestly rather than sharply.
    var fluidMlPerKg: Double {
        switch self {
        case .under40, .fortyToFiftyFour: return 35
        case .fiftyFiveToSixtyNine: return 33
        case .seventyToSeventyNine: return 31
        case .eightyPlus: return 30
        }
    }

    /// Whether balance and bone-loading work should be non-negotiable.
    /// Falls, not cardio, are what ends independence.
    var needsBalanceWork: Bool {
        switch self {
        case .under40, .fortyToFiftyFour: return false
        case .fiftyFiveToSixtyNine, .seventyToSeventyNine, .eightyPlus: return true
        }
    }

    /// Whether a daily protein emphasis should be surfaced in meal planning.
    var needsProteinEmphasis: Bool {
        switch self {
        case .under40, .fortyToFiftyFour: return false
        default: return true
        }
    }
}
