import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper so haptics can be muted in one place for anyone who finds them
/// unpleasant — a real accessibility need, not a preference.
enum Haptics {

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics.enabled") as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "haptics.enabled")
    }

    static func tap() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func complete() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func celebrate() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            generator.impactOccurred(intensity: 0.7)
        }
        #endif
    }

    static func warn() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
