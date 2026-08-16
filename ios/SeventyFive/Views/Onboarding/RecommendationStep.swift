import SwiftUI

/// Final onboarding screen: shows the recommendation, lets the user override it,
/// and previews the exact plan before anything is committed.
struct RecommendationStep: View {
    let draft: OnboardingDraft
    let onStart: (ChallengeTier) -> Void

    @State private var chosenTier: ChallengeTier?
    @State private var showFullPlan = false

    private var profile: UserProfile { draft.previewProfile() }
    private var recommendation: TierEngine.Recommendation { TierEngine.recommendTier(for: profile) }
    private var tier: ChallengeTier { chosenTier ?? recommendation.tier }
    private var ruleSet: RuleSet { TierEngine.buildRules(tier: tier, profile: profile) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(recommendation.headline)
                    .font(.largeTitle.bold())

                ForEach(recommendation.reasons, id: \.self) { reason in
                    Label {
                        Text(reason).font(.callout)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    }
                }

                ForEach(recommendation.cautions, id: \.self) { caution in
                    SafetyNote(text: caution)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Pick your tier")
                    .font(.title3.weight(.semibold))
                Text("You can change this later without losing your history.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)

                ForEach(ChallengeTier.allCases.reversed()) { option in
                    TierCard(
                        tier: option,
                        isSelected: tier == option,
                        isRecommended: recommendation.tier == option
                    ) {
                        chosenTier = option
                    }
                }
            }

            planPreview

            Button {
                onStart(tier)
            } label: {
                Text("Start day 1")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.tierColor(tier))
        }
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your daily plan")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(showFullPlan ? "Less" : "Show why") {
                    withAnimation { showFullPlan.toggle() }
                }
                .font(.footnote.weight(.medium))
            }

            ForEach(ruleSet.rules) { rule in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: rule.iconName)
                            .foregroundStyle(Theme.kindColor(rule.kind))
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rule.title).font(.body.weight(.medium))
                            Text(rule.detail).font(.caption).foregroundStyle(Theme.subtle)
                        }
                        Spacer()
                        Text(rule.targetDescription)
                            .font(.callout.weight(.semibold).monospacedDigit())
                        if !rule.isRequired {
                            TagPill(text: "optional", tint: Theme.subtle)
                        }
                    }

                    if showFullPlan {
                        ForEach(rule.adaptations, id: \.self) { note in
                            Text("• \(note)")
                                .font(.caption)
                                .foregroundStyle(Theme.subtle)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(rule.safetyFlags, id: \.self) { flag in
                            Text("⚠︎ \(flag)")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 6)

                if rule.id != ruleSet.rules.last?.id {
                    Divider()
                }
            }

            ForEach(ruleSet.globalNotes, id: \.self) { note in
                SafetyNote(text: note, isCritical: note.contains("doctor"))
            }
        }
        .card(tint: Theme.tierColor(tier))
    }
}

struct TierCard: View {
    let tier: ChallengeTier
    let isSelected: Bool
    var isRecommended: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: tier.accentSymbol)
                        .foregroundStyle(Theme.tierColor(tier))
                    Text(tier.displayName)
                        .font(.headline)
                    if isRecommended {
                        TagPill(text: "recommended", systemImage: "sparkles", tint: Theme.success)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? Theme.tierColor(tier) : Theme.subtle)
                }
                Text(tier.tagline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.tierColor(tier))
                Text(tier.blurb)
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.tierColor(tier) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Shown between runs — after a restart or a completed challenge.
struct TierSelectionView: View {
    @Environment(ChallengeStore.self) private var store
    let profile: UserProfile
    let isOnboarding: Bool

    @State private var tier: ChallengeTier = .medium

    private var recommendation: TierEngine.Recommendation { TierEngine.recommendTier(for: profile) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Ready for another run?")
                        .font(.largeTitle.bold())

                    Text("Your previous attempts are kept. Nothing you did is erased by starting again.")
                        .font(.callout)
                        .foregroundStyle(Theme.subtle)

                    ForEach(ChallengeTier.allCases.reversed()) { option in
                        TierCard(
                            tier: option,
                            isSelected: tier == option,
                            isRecommended: recommendation.tier == option
                        ) { tier = option }
                    }

                    Button {
                        store.startRun(tier: tier, profile: profile)
                    } label: {
                        Text("Start day 1").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.tierColor(tier))
                }
                .padding(20)
            }
            .navigationTitle("New run")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { tier = recommendation.tier }
        }
    }
}
