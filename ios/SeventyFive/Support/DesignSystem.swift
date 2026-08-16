import SwiftUI

/// Visual language for the app.
///
/// Two rules drive everything here: minimum 17pt body text with Dynamic Type
/// respected all the way to the accessibility sizes, and a 44pt minimum tap
/// target. Both matter more than usual for the audience this app is built for.
enum Theme {

    // MARK: - Colour

    static let ink = Color.primary
    static let subtle = Color.secondary

    static func tierColor(_ tier: ChallengeTier) -> Color {
        switch tier {
        case .soft: return Color(red: 0.20, green: 0.60, blue: 0.45)
        case .medium: return Color(red: 0.87, green: 0.53, blue: 0.13)
        case .hard: return Color(red: 0.78, green: 0.22, blue: 0.24)
        }
    }

    static func kindColor(_ kind: TaskKind) -> Color {
        switch kind {
        case .workout, .movementSnack: return Color(red: 0.85, green: 0.35, blue: 0.25)
        case .outdoorWorkout: return Color(red: 0.90, green: 0.63, blue: 0.15)
        case .hydration: return Color(red: 0.18, green: 0.55, blue: 0.83)
        case .nutrition: return Color(red: 0.35, green: 0.62, blue: 0.30)
        case .reading: return Color(red: 0.45, green: 0.40, blue: 0.75)
        case .progressPhoto: return Color(red: 0.55, green: 0.45, blue: 0.40)
        case .mobilityWork, .balanceWork: return Color(red: 0.25, green: 0.62, blue: 0.60)
        case .sleep: return Color(red: 0.35, green: 0.35, blue: 0.55)
        case .reflection: return Color(red: 0.60, green: 0.45, blue: 0.55)
        }
    }

    static let coinColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    static let success = Color(red: 0.20, green: 0.60, blue: 0.35)
    static let warning = Color(red: 0.85, green: 0.55, blue: 0.10)
    static let danger = Color(red: 0.78, green: 0.22, blue: 0.24)

    // MARK: - Metrics

    static let cardCorner: CGFloat = 18
    static let minimumTapTarget: CGFloat = 48
    static let cardPadding: CGFloat = 18
    static let stackSpacing: CGFloat = 14
}

// MARK: - Reusable surfaces

struct CardBackground: ViewModifier {
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(tint.opacity(0.25), lineWidth: tint == .clear ? 0 : 1.5)
            )
    }
}

extension View {
    func card(tint: Color = .clear) -> some View {
        modifier(CardBackground(tint: tint))
    }

    /// Guarantees a comfortable hit area no matter how small the label is.
    func comfortableTapTarget() -> some View {
        frame(minWidth: Theme.minimumTapTarget, minHeight: Theme.minimumTapTarget)
            .contentShape(Rectangle())
    }
}

/// Section header used across every tab.
struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(Theme.subtle)
                }
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Big circular progress indicator used on Today and Progress.
struct ProgressRing: View {
    var fraction: Double
    var lineWidth: CGFloat = 14
    var tint: Color = .accentColor
    var label: String
    var caption: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
                    .multilineTextAlignment(.center)
            }
            .padding(lineWidth * 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(caption). \(Int(fraction * 100)) percent.")
    }
}

/// Pill used for tags, filters and flags.
struct TagPill: View {
    let text: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.15), in: Capsule())
        .foregroundStyle(tint)
    }
}

/// Standard "nothing here yet" state.
struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(Theme.subtle)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.subtle)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

/// A callout for safety information. Deliberately visually distinct from the
/// motivational copy — this is the part that should never read as marketing.
struct SafetyNote: View {
    let text: String
    var isCritical: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isCritical ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(isCritical ? Theme.danger : Theme.warning)
                .font(.callout)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((isCritical ? Theme.danger : Theme.warning).opacity(0.12))
        )
    }
}
