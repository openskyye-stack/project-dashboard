import SwiftUI

/// A question with its reasoning attached.
///
/// Every question in this app shows *why* it's being asked. People answer
/// honestly about pain and falls when they can see what the answer is for, and
/// evasively when it looks like data collection.
struct QuestionBlock<Content: View>: View {
    let question: String
    var why: String?
    @ViewBuilder var content: Content

    @State private var showWhy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let why {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showWhy.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showWhy ? "chevron.down" : "questionmark.circle")
                        Text(showWhy ? "Hide" : "Why we ask")
                    }
                    .font(.footnote.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)

                if showWhy {
                    Text(why)
                        .font(.footnote)
                        .foregroundStyle(Theme.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Single-choice row with a generous tap target.
struct SelectableRow: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Theme.subtle)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let symbol {
                            Image(systemName: symbol).foregroundStyle(Theme.subtle)
                        }
                        Text(title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.subtle)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(minHeight: Theme.minimumTapTarget)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Multi-choice row.
struct MultiSelectRow: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Theme.subtle)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let symbol {
                            Image(systemName: symbol).foregroundStyle(Theme.subtle)
                        }
                        Text(title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                    }
                    if isSelected, let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.subtle)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(minHeight: Theme.minimumTapTarget)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Big plus/minus stepper. Far easier to hit than a slider for anyone with
/// tremor or reduced fine motor control, and it reads its value aloud properly.
struct LabelledStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack(spacing: 16) {
            stepperButton(symbol: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }

            Text(format(value))
                .font(.title2.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            stepperButton(symbol: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func stepperButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

struct HourPicker: View {
    let title: String
    @Binding var hour: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Picker(title, selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(HourPicker.label(for: value)).tag(value)
                }
            }
            .pickerStyle(.menu)
        }
    }

    static func label(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

/// Horizontal chip row used for filters.
struct FilterChip: View {
    let title: String
    var systemImage: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption)
                }
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isOn ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isOn ? Color.white : Theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}
