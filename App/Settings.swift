import SwiftUI
import UIKit

/// Player settings, stored in UserDefaults. Defaults to everything on.
enum Settings {
    static var soundOn: Bool {
        get { UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundOn") }
    }

    static var hapticsOn: Bool {
        get { UserDefaults.standard.object(forKey: "hapticsOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsOn") }
    }

    static var musicOn: Bool {
        get { UserDefaults.standard.object(forKey: "musicOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "musicOn") }
    }
}

/// Haptics that respect the player's toggle.
@MainActor
enum Haptics {
    static func impact() {
        guard Settings.hapticsOn else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard Settings.hapticsOn else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
