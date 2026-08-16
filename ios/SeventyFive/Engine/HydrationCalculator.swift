import Foundation

enum HydrationFormatter {
    static func short(milliliters: Double) -> String {
        if UnitPreference.usesImperial {
            let oz = milliliters / 29.5735
            if oz >= 128 {
                let gallons = oz / 128
                return String(format: "%.2f gal", gallons)
            }
            return "\(Int(oz.rounded())) oz"
        }
        if milliliters >= 1000 {
            return String(format: "%.1f L", milliliters / 1000)
        }
        return "\(Int(milliliters.rounded())) ml"
    }

    static func glasses(milliliters: Double, glassSize: Double = 250) -> Int {
        guard glassSize > 0 else { return 0 }
        return Int((milliliters / glassSize).rounded())
    }
}

enum UnitPreference {
    /// Follows the device locale. 75 Hard's canonical "a gallon" only reads as a
    /// gallon to some of the world.
    static var usesImperial: Bool {
        Locale.current.measurementSystem == .us
    }
}

/// Works out a daily fluid target that is defensible for the person in front of
/// us rather than copying "one gallon" onto everybody.
///
/// The classic 75 Hard rule is a US gallon (3785 ml) regardless of body size,
/// age, climate or kidney function. For a 55 kg eighty-year-old on a diuretic,
/// that is not a challenge, it is a hyponatraemia risk. So the target is built
/// from body weight and age, nudged by tier, and then hard-capped by any
/// condition that limits fluids.
enum HydrationCalculator {

    /// Absolute ceiling for anyone, regardless of tier. Healthy kidneys clear
    /// roughly 0.8–1.0 L/hour; sustained intake beyond this offers nothing.
    static let absoluteCeilingML: Double = 4000

    /// Ceiling applied when a condition or medication limits fluid intake.
    /// Deliberately conservative — the real number has to come from a clinician.
    static let restrictedCeilingML: Double = 1500

    struct Result {
        var targetML: Double
        var notes: [String]
        var isCapped: Bool
        var requiresClinicianInput: Bool
        var glassCount: Int
    }

    static func dailyTarget(for profile: UserProfile, tier: ChallengeTier) -> Result {
        var notes: [String] = []

        let perKg = profile.ageBand.fluidMlPerKg
        var target = profile.weightKg * perKg

        notes.append("Based on \(Int(perKg)) ml per kg at \(Int(profile.weightKg)) kg.")

        // Tier nudges the target up, but never off the physiological map.
        switch tier {
        case .hard:
            target *= 1.15
            notes.append("75 Hard adds 15% on top.")
        case .medium:
            target *= 1.05
            notes.append("75 Medium adds 5% on top.")
        case .soft:
            notes.append("75 Soft keeps the baseline target.")
        }

        // Reduced mobility usually means lower sweat losses across the day.
        if profile.mobility == .seated || profile.mobility == .usesWalkingAid {
            target *= 0.92
            notes.append("Trimmed slightly for lower daily sweat loss.")
        }

        var isCapped = false
        var requiresClinician = false

        if profile.hasHydrationCap {
            target = min(target, restrictedCeilingML)
            isCapped = true
            requiresClinician = true
            notes.append("Capped because you told us your fluids are limited. Replace this number with the one your clinician gives you.")
        }

        if target > absoluteCeilingML {
            target = absoluteCeilingML
            isCapped = true
            notes.append("Capped at 4 L — more than this does nothing useful.")
        }

        // Round to a whole number of 250 ml glasses so the tracker is tappable.
        target = (target / 250).rounded() * 250
        target = max(1000, target)

        if profile.age >= 65 && !profile.hasHydrationCap {
            notes.append("Thirst gets less reliable with age, so drink to the schedule rather than waiting to feel thirsty.")
        }

        return Result(
            targetML: target,
            notes: notes,
            isCapped: isCapped,
            requiresClinicianInput: requiresClinician,
            glassCount: HydrationFormatter.glasses(milliliters: target)
        )
    }

    /// Evenly spaced reminder times between waking and wind-down, front-loaded
    /// so the last third of the day stays light — nobody wants to be up at 3am
    /// because an app told them to drink at 9pm.
    static func reminderHours(for profile: UserProfile, glassCount: Int) -> [Int] {
        let start = max(5, min(profile.preferredStartHour, 11))
        // Stop drinking on schedule two hours before wind-down.
        let end = max(start + 3, profile.preferredWindDownHour - 2)
        let reminders = min(max(3, glassCount / 2), 8)
        guard reminders > 1 else { return [start] }

        let span = Double(end - start)
        return (0..<reminders).map { index in
            let fraction = Double(index) / Double(reminders - 1)
            return start + Int((span * fraction).rounded())
        }
    }
}
