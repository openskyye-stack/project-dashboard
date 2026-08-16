import Foundation

/// The morning check-in, and what the app does with the answers.
///
/// This is the piece that makes the challenge survivable for an older body. A
/// fixed plan meets a variable body; without a scaling rule, the only options on
/// a bad day are "push through and get hurt" or "miss and reset". This adds a
/// third: do a smaller version that still counts.
enum DayScaler {

    struct CheckIn {
        var sleepHours: Double
        var painScore: Int      // 0–10
        var energyScore: Int    // 1–5
        var sorenessScore: Int  // 1–5

        static let neutral = CheckIn(sleepHours: 7, painScore: 0, energyScore: 3, sorenessScore: 1)
    }

    struct Outcome {
        var scaleFactor: Double
        var headline: String
        var reason: String
        var advice: [String]
        var suggestsRest: Bool
        var suggestsClinician: Bool
    }

    /// Questions asked each morning. Short on purpose — a check-in that takes a
    /// minute gets skipped.
    static let questions: [String] = [
        "How many hours did you sleep?",
        "Worst pain right now, 0 to 10?",
        "Energy today?",
        "How sore are you from yesterday?"
    ]

    static func evaluate(_ checkIn: CheckIn, profile: UserProfile) -> Outcome {
        var scale = 1.0
        var reasons: [String] = []
        var advice: [String] = []
        var suggestsRest = false
        var suggestsClinician = false

        // Pain is the dominant signal.
        switch checkIn.painScore {
        case 0...2:
            break
        case 3...4:
            scale -= 0.15
            reasons.append("pain at \(checkIn.painScore)")
            advice.append("Choose a low-impact modality today. Water or a bike if you have them.")
        case 5...6:
            scale -= 0.35
            reasons.append("pain at \(checkIn.painScore)")
            advice.append("Halve the load, keep the habit. Movement usually helps pain at this level — sharp pain is the exception.")
        default:
            scale -= 0.55
            reasons.append("pain at \(checkIn.painScore)")
            suggestsRest = true
            advice.append("This is a day for gentle range of motion, not training.")
            if checkIn.painScore >= 8 {
                suggestsClinician = true
            }
        }

        // Sleep debt.
        if checkIn.sleepHours < 5 {
            scale -= 0.2
            reasons.append("under five hours' sleep")
            advice.append("On short sleep, injury risk climbs and technique slips. Keep it simple and familiar.")
        } else if checkIn.sleepHours < 6.5 {
            scale -= 0.1
            reasons.append("short sleep")
        }

        // Energy.
        if checkIn.energyScore <= 1 {
            scale -= 0.2
            reasons.append("very low energy")
        } else if checkIn.energyScore == 2 {
            scale -= 0.1
            reasons.append("low energy")
        } else if checkIn.energyScore == 5 && checkIn.painScore <= 2 {
            advice.append("Good day to take the harder option if you've been coasting.")
        }

        // Soreness.
        if checkIn.sorenessScore >= 4 {
            scale -= 0.15
            reasons.append("heavy soreness")
            advice.append("Work different muscles than yesterday rather than resting completely.")
        }

        // Age-related floor: older bodies deload more and recover slower, so the
        // floor is higher — we'd rather they do 40% than nothing.
        let floor: Double
        switch profile.ageBand {
        case .under40, .fortyToFiftyFour: floor = 0.4
        case .fiftyFiveToSixtyNine: floor = 0.45
        case .seventyToSeventyNine, .eightyPlus: floor = 0.5
        }

        scale = max(floor, min(1.0, scale))
        scale = (scale * 20).rounded() / 20 // nearest 5%

        let headline: String
        if scale >= 0.98 {
            headline = "Full plan today"
        } else if scale >= 0.8 {
            headline = "Slightly lighter today"
        } else if scale >= 0.6 {
            headline = "Deload day"
        } else {
            headline = "Minimum effective day"
        }

        let reason: String
        if reasons.isEmpty {
            reason = "Nothing in your check-in suggests holding back."
        } else {
            reason = "Scaled to \(Int(scale * 100))% for \(listPhrase(reasons)). It still counts as a completed day."
        }

        if suggestsClinician {
            advice.append("Pain at this level for more than a couple of days is worth a phone call to your doctor.")
        }
        if profile.considerations.contains(.diabetes) && checkIn.energyScore <= 2 {
            advice.append("Check your blood glucose before you train.")
        }

        return Outcome(
            scaleFactor: scale,
            headline: headline,
            reason: reason,
            advice: advice,
            suggestsRest: suggestsRest,
            suggestsClinician: suggestsClinician
        )
    }

    /// Applies the day's scale factor to a rule's target.
    /// Hydration and binary rules are never scaled — you don't drink less
    /// because you slept badly, and "stuck to the plan" has no 70% version.
    static func scaledTarget(for rule: TaskRule, scaleFactor: Double) -> Double {
        guard scaleFactor < 1 else { return rule.target }
        switch rule.unit {
        case .yesNo, .milliliters:
            return rule.target
        case .minutes:
            return max(5, (rule.target * scaleFactor / 5).rounded() * 5)
        case .pages:
            return max(1, (rule.target * scaleFactor).rounded())
        case .sessions, .count:
            return max(1, (rule.target * scaleFactor).rounded())
        }
    }

    private static func listPhrase(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            return items.dropLast().joined(separator: ", ") + " and " + (items.last ?? "")
        }
    }
}
