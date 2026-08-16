import SwiftUI

/// One task on the Today screen.
///
/// The completion circle is 52pt and the steppers are 44pt because this app is
/// used by people with arthritic hands and by people mid-workout with shaky
/// arms. Small controls are the single most common accessibility failure in
/// fitness apps.
struct TaskCard: View {
    let rule: TaskRule
    let entry: TaskEntry?
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onToggle: () -> Void
    let onDetail: () -> Void

    private var fraction: Double { entry?.fraction ?? 0 }
    private var isDone: Bool { entry?.isSatisfied ?? false }
    private var tint: Color { Theme.kindColor(rule.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                completionButton

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: rule.iconName)
                            .foregroundStyle(tint)
                        Text(rule.title)
                            .font(.headline)
                            .strikethrough(isDone, color: Theme.subtle)
                        if !rule.isRequired {
                            TagPill(text: "optional", tint: Theme.subtle)
                        }
                    }

                    Text(rule.detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.subtle)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(progressText)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isDone ? Theme.success : Theme.ink)
                        if let chunk = rule.chunkDescription, !isDone {
                            Text("· \(chunk)")
                                .font(.caption)
                                .foregroundStyle(Theme.subtle)
                        }
                    }
                }

                Spacer(minLength: 0)

                Button(action: onDetail) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.subtle)
                        .comfortableTapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details and options for \(rule.title)")
            }

            if !rule.isBinary {
                ProgressView(value: max(0, min(1, fraction)))
                    .tint(tint)

                HStack(spacing: 12) {
                    stepButton(symbol: "minus", action: onDecrement)
                        .disabled((entry?.value ?? 0) <= 0)
                    stepButton(symbol: "plus", action: onIncrement)
                    Spacer()
                    Text(stepHint)
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
            }

            if !rule.safetyFlags.isEmpty {
                ForEach(rule.safetyFlags.prefix(2), id: \.self) { flag in
                    Label(flag, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card(tint: isDone ? Theme.success : .clear)
        .accessibilityElement(children: .contain)
    }

    private var completionButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .stroke(isDone ? Theme.success : tint.opacity(0.4), lineWidth: 3)
                    .frame(width: 44, height: 44)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.success)
                } else if fraction > 0 {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "\(rule.title) complete. Tap to undo." : "Mark \(rule.title) complete")
        .accessibilityAddTraits(isDone ? [.isSelected, .isButton] : .isButton)
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint.opacity(0.15)))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Add \(rule.unit.format(rule.unit.step))" : "Remove \(rule.unit.format(rule.unit.step))")
    }

    private var progressText: String {
        guard let entry else { return rule.targetDescription }
        if rule.isBinary { return isDone ? "Done" : "Not yet" }
        return "\(rule.unit.format(entry.value)) of \(rule.unit.format(entry.target))"
    }

    private var stepHint: String {
        "± \(rule.unit.format(rule.unit.step))"
    }
}
