import SwiftUI

/// The payoff moment. Short, loud, and gone — a celebration that needs
/// dismissing twice stops being a reward.
struct CelebrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let celebration: ChallengeStore.Celebration

    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: celebration.symbolName)
                .font(.system(size: 88))
                .foregroundStyle(Theme.success)
                .scaleEffect(animate || reduceMotion ? 1 : 0.5)
                .opacity(animate || reduceMotion ? 1 : 0)

            VStack(spacing: 10) {
                Text(celebration.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(celebration.message)
                    .font(.callout)
                    .foregroundStyle(Theme.subtle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            if celebration.coins > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "circle.hexagongrid.fill")
                    Text("+\(celebration.coins) Grit Coins")
                        .font(.title3.weight(.bold))
                }
                .foregroundStyle(Theme.coinColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.coinColor.opacity(0.15)))
            }

            if !celebration.achievements.isEmpty {
                VStack(spacing: 12) {
                    Text("Unlocked")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.subtle)

                    ForEach(celebration.achievements) { achievement in
                        HStack(spacing: 12) {
                            Image(systemName: achievement.symbolName)
                                .font(.title2)
                                .foregroundStyle(Theme.coinColor)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title).font(.body.weight(.semibold))
                                Text(achievement.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.subtle)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Nice").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            guard !reduceMotion else { animate = true; return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                animate = true
            }
        }
    }
}
