import Foundation

/// Turns a tier plus a person into a concrete, safe daily rule set.
///
/// Every adjustment records a plain-language reason, which the app shows back to
/// the user. Nobody should have to guess why their workout says 28 minutes when
/// the internet says 45.
enum TierEngine {

    // MARK: - Nominal (unadapted) values

    private struct Baseline {
        var primaryWorkoutMinutes: Double
        var secondaryWorkoutMinutes: Double?
        var readingPages: Double
        var requiresPhoto: Bool
        var requiresSecondOutdoor: Bool
        var dietStrictness: String
        var includesReflection: Bool
    }

    private static func baseline(for tier: ChallengeTier) -> Baseline {
        switch tier {
        case .hard:
            return Baseline(
                primaryWorkoutMinutes: 45,
                secondaryWorkoutMinutes: 45,
                readingPages: 10,
                requiresPhoto: true,
                requiresSecondOutdoor: true,
                dietStrictness: "No treat meals, no alcohol. Pick a plan and hold it.",
                includesReflection: false
            )
        case .medium:
            return Baseline(
                primaryWorkoutMinutes: 45,
                secondaryWorkoutMinutes: 20,
                readingPages: 10,
                requiresPhoto: true,
                requiresSecondOutdoor: false,
                dietStrictness: "Whole foods by default. One planned treat meal a week, no alcohol on training days.",
                includesReflection: true
            )
        case .soft:
            return Baseline(
                primaryWorkoutMinutes: 45,
                secondaryWorkoutMinutes: nil,
                readingPages: 10,
                requiresPhoto: false,
                requiresSecondOutdoor: false,
                dietStrictness: "Mostly whole foods, protein at every meal, alcohol only on occasions.",
                includesReflection: true
            )
        }
    }

    // MARK: - Build

    static func buildRules(tier: ChallengeTier, profile: UserProfile) -> RuleSet {
        let base = baseline(for: tier)
        var rules: [TaskRule] = []
        var globalNotes: [String] = []

        let safetyFlags = MobilityAdaptation.safetyFlags(for: profile)
        let policy = MobilityAdaptation.outdoorPolicy(for: profile)

        // --- Duration adaptation ---------------------------------------------
        let ageMultiplier = profile.ageBand.durationMultiplier
        let painMultiplier = profile.jointPain.durationMultiplier
        var durationNotes: [String] = []

        if ageMultiplier < 1 {
            durationNotes.append("Shortened for the \(profile.ageBand.displayName) band — same stimulus, less accumulated joint load.")
        }
        if painMultiplier < 1 {
            durationNotes.append("Shortened again for \(profile.jointPain.displayName.lowercased()) joint pain.")
        }

        var primary = base.primaryWorkoutMinutes * ageMultiplier * painMultiplier
        primary = max(15, (primary / 5).rounded() * 5)

        var secondary = base.secondaryWorkoutMinutes.map { $0 * ageMultiplier * painMultiplier }
        if let value = secondary {
            secondary = max(10, (value / 5).rounded() * 5)
        }

        // --- Time budget ------------------------------------------------------
        // Never prescribe more movement than the person told us they have.
        let movementBudget = Double(max(20, profile.availableMinutesPerDay - 25)) // leave room for reading, meals, photo
        let requested = primary + (secondary ?? 0)
        if requested > movementBudget {
            let scale = movementBudget / requested
            primary = max(15, (primary * scale / 5).rounded() * 5)
            if let value = secondary {
                secondary = max(10, (value * scale / 5).rounded() * 5)
            }
            durationNotes.append("Trimmed to fit the \(profile.availableMinutesPerDay) minutes a day you said you actually have.")
            globalNotes.append("Your plan is sized to your real schedule. A plan you can finish beats a plan you admire.")
        }

        // --- Splitting --------------------------------------------------------
        // Someone who can stand for 10 minutes should not be handed a 45-minute block.
        var splits = 1
        if profile.continuousStandingMinutes > 0 && primary > Double(profile.continuousStandingMinutes) {
            splits = min(4, Int(ceil(primary / Double(max(5, profile.continuousStandingMinutes)))))
            if splits > 1 {
                durationNotes.append("Split into \(splits) chunks because you told us you can keep going for about \(profile.continuousStandingMinutes) minutes at a time. Broken-up movement counts exactly the same.")
            }
        }

        // --- Rule 1: primary workout -----------------------------------------
        let indoorFirst = policy == .indoorWithFreshAir || !base.requiresSecondOutdoor
        rules.append(
            TaskRule(
                id: "workout.primary",
                kind: .workout,
                title: "Main workout",
                detail: indoorFirst
                    ? "Your choice of modality. Effort matters more than the exercise."
                    : "Indoors or out — the second session is the one that has to be outside.",
                target: primary,
                unit: .minutes,
                xpValue: 30,
                maxSplits: splits,
                adaptations: durationNotes,
                safetyFlags: safetyFlags
            )
        )

        // --- Rule 2: second session ------------------------------------------
        if let secondaryMinutes = secondary {
            var secondaryNotes = durationNotes
            var title = "Second session"
            var detail = policy.detail

            switch policy {
            case .fullyOutdoor:
                title = "Outdoor session"
            case .outdoorWithConditions:
                title = "Outdoor session"
                secondaryNotes.append("Bad conditions move this indoors without breaking your streak. Ice and heatwaves are not character tests.")
            case .doorstepOrSheltered:
                title = "Fresh-air session"
                secondaryNotes.append("Rewritten as a doorstep session — you told us balance or footing is a concern, and a fall would end this challenge far faster than a missed walk.")
            case .indoorWithFreshAir:
                title = "Second session"
                detail = "Indoors. Open a window or step outside for a few minutes either side."
                secondaryNotes.append("The outdoor requirement became an indoor one because getting outside daily isn't realistic for you.")
            }

            rules.append(
                TaskRule(
                    id: "workout.secondary",
                    kind: policy == .indoorWithFreshAir ? .workout : .outdoorWorkout,
                    title: title,
                    detail: detail,
                    target: secondaryMinutes,
                    unit: .minutes,
                    xpValue: 25,
                    maxSplits: max(1, splits - 1),
                    adaptations: secondaryNotes,
                    safetyFlags: safetyFlags
                )
            )
        } else {
            // Soft tier still gets outside, just without a duration demand.
            rules.append(
                TaskRule(
                    id: "outdoor.presence",
                    kind: .outdoorWorkout,
                    title: "Get outside",
                    detail: policy.detail,
                    target: 10,
                    unit: .minutes,
                    xpValue: 15,
                    maxSplits: 2,
                    adaptations: ["75 Soft asks for fresh air rather than a second workout."],
                    safetyFlags: []
                )
            )
        }

        // --- Rule 3: balance and bone work -----------------------------------
        // Added for anyone 55+ or with a fall history. This is the single highest
        // value addition for an older participant and the original challenge omits it.
        if profile.ageBand.needsBalanceWork || profile.isFallRisk || profile.considerations.contains(.osteoporosis) {
            var reason = "Added because balance is what protects independence — and the original challenge has nothing in it that trains balance."
            if profile.isFallRisk {
                reason = "Added and prioritised: you flagged unsteadiness or a fall in the last year."
            }
            rules.append(
                TaskRule(
                    id: "balance.daily",
                    kind: .balanceWork,
                    title: "Balance & steadiness",
                    detail: "Heel-to-toe stands, weight shifts, sit-to-stands. One hand on a counter throughout.",
                    target: 5,
                    unit: .minutes,
                    isRequired: tier != .soft,
                    xpValue: 20,
                    maxSplits: 2,
                    adaptations: [reason],
                    safetyFlags: ["Always within arm's reach of a solid support."]
                )
            )
        }

        // --- Rule 4: hydration -------------------------------------------------
        let hydration = HydrationCalculator.dailyTarget(for: profile, tier: tier)
        var hydrationFlags: [String] = []
        if hydration.requiresClinicianInput {
            hydrationFlags.append("Confirm this number with your clinician before following it.")
        }
        rules.append(
            TaskRule(
                id: "hydration",
                kind: .hydration,
                title: "Water",
                detail: "\(hydration.glassCount) glasses across the day. Sip steadily rather than catching up at night.",
                target: hydration.targetML,
                unit: .milliliters,
                xpValue: 20,
                maxSplits: hydration.glassCount,
                adaptations: hydration.notes,
                safetyFlags: hydrationFlags
            )
        )
        if hydration.isCapped {
            globalNotes.append("Your water target is capped for safety. That is not a lesser version of the challenge.")
        }

        // --- Rule 5: nutrition ---------------------------------------------------
        var dietNotes: [String] = []
        if profile.ageBand.needsProteinEmphasis {
            let proteinTarget = Int((profile.weightKg * 1.2).rounded())
            dietNotes.append("Aim for about \(proteinTarget) g of protein daily. Muscle is harder to keep after 55 and protein is the lever.")
        }
        if profile.considerations.contains(.diabetes) {
            dietNotes.append("Keep carbohydrate steady across meals rather than saving it for the evening.")
        }
        if profile.dietary.contains(.lowSodium) {
            dietNotes.append("Recipes are filtered to the lower-sodium set.")
        }
        rules.append(
            TaskRule(
                id: "nutrition",
                kind: .nutrition,
                title: "Stick to the plan",
                detail: baseline(for: tier).dietStrictness,
                target: 1,
                unit: .yesNo,
                allowsPartialCredit: false,
                xpValue: 30,
                adaptations: dietNotes
            )
        )

        // --- Rule 6: reading -----------------------------------------------------
        var readingDetail = "Non-fiction. Something that changes how you do things."
        var readingNotes: [String] = []
        var readingUnit = MeasureUnit.pages
        var readingTarget = base.readingPages

        if profile.readingFormat == .audiobook {
            readingUnit = .minutes
            readingTarget = 15
            readingDetail = "Fifteen minutes of non-fiction listening."
            readingNotes.append("Converted from pages to minutes because you're listening. Fifteen minutes is roughly ten pages.")
        }
        rules.append(
            TaskRule(
                id: "reading",
                kind: .reading,
                title: "Read",
                detail: readingDetail,
                target: readingTarget,
                unit: readingUnit,
                xpValue: 20,
                maxSplits: 3,
                adaptations: readingNotes
            )
        )

        // --- Rule 7: progress photo ---------------------------------------------
        if base.requiresPhoto {
            rules.append(
                TaskRule(
                    id: "photo",
                    kind: .progressPhoto,
                    title: "Progress photo",
                    detail: "Same spot, same light. It stays on this device.",
                    target: 1,
                    unit: .yesNo,
                    isRequired: tier == .hard,
                    allowsPartialCredit: false,
                    xpValue: 10
                )
            )
        }

        // --- Rule 8: reflection ---------------------------------------------------
        if base.includesReflection {
            rules.append(
                TaskRule(
                    id: "reflection",
                    kind: .reflection,
                    title: "One line about today",
                    detail: "What worked, what hurt, what you'd change tomorrow.",
                    target: 1,
                    unit: .yesNo,
                    isRequired: false,
                    allowsPartialCredit: false,
                    xpValue: 10
                )
            )
        }

        // --- Global notes ---------------------------------------------------------
        if profile.shouldPromptClinicianCheck {
            globalNotes.append("Talk to your doctor before you start. This app adapts the plan, it doesn't know your medical history.")
        }
        if splits > 1 {
            globalNotes.append("Broken-up movement counts. Three short walks are not a worse version of one long one.")
        }
        if tier == .hard && (profile.age >= 70 || profile.mobility != .unrestricted) {
            globalNotes.append("75 Hard's zero-tolerance restart rule is brutal by design. If it starts costing you sleep or pushing you through pain, stepping down to 75 Medium is a strategy, not a failure.")
        }

        return RuleSet(tier: tier, rules: rules, globalNotes: globalNotes)
    }

    // MARK: - Recommendation

    struct Recommendation {
        var tier: ChallengeTier
        var headline: String
        var reasons: [String]
        var cautions: [String]
    }

    /// Suggests a tier from the interview answers. The user can always override —
    /// this is advice, not a gate.
    static func recommendTier(for profile: UserProfile) -> Recommendation {
        var score = 0
        var reasons: [String] = []
        var cautions: [String] = []

        switch profile.ageBand {
        case .under40: score += 2
        case .fortyToFiftyFour: score += 1
        case .fiftyFiveToSixtyNine: score += 0
        case .seventyToSeventyNine: score -= 1
        case .eightyPlus: score -= 2
        }

        switch profile.mobility {
        case .unrestricted: score += 1
        case .mildLimitation: score += 0
        case .moderateLimitation: score -= 1
        case .usesWalkingAid, .seated: score -= 2
        }

        switch profile.jointPain {
        case .none: score += 1
        case .mild: score += 0
        case .moderate: score -= 1
        case .severe: score -= 2
        }

        let seriousConditions = profile.considerations.filter { $0 != .none && ($0.capsIntensity || $0.capsHydration) }
        if !seriousConditions.isEmpty {
            score -= seriousConditions.count
            cautions.append("You flagged \(seriousConditions.map(\.displayName).joined(separator: ", ")). The plan is capped accordingly.")
        }

        if profile.availableMinutesPerDay >= 100 {
            score += 1
            reasons.append("You have \(profile.availableMinutesPerDay) minutes a day, which is enough for a two-session tier.")
        } else if profile.availableMinutesPerDay < 60 {
            score -= 1
            reasons.append("Under an hour a day realistically supports one solid session, not two.")
        }

        if profile.isFallRisk {
            score -= 1
            cautions.append("Fall risk moves the outdoor requirement to level, familiar ground.")
        }

        let tier: ChallengeTier
        if score >= 4 {
            tier = .hard
        } else if score >= 1 {
            tier = .medium
        } else {
            tier = .soft
        }

        switch tier {
        case .hard:
            reasons.insert("Nothing in your answers argues against the full version.", at: 0)
        case .medium:
            reasons.insert("75 Medium gives you real demands and a grace day, which is the difference between finishing and restarting.", at: 0)
        case .soft:
            reasons.insert("75 Soft is the right starting point — it never resets you to day one, so a bad day costs a day rather than ten weeks.", at: 0)
        }

        if profile.ageBand == .seventyToSeventyNine || profile.ageBand == .eightyPlus {
            reasons.append("At \(profile.age), consistency over 75 days is worth far more than intensity in any single one of them.")
        }

        return Recommendation(
            tier: tier,
            headline: "We'd start you on \(tier.displayName)",
            reasons: reasons,
            cautions: cautions
        )
    }
}
