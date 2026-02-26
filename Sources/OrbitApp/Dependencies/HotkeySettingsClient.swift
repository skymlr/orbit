import Dependencies
import Foundation

struct HotkeySettingsClient: Sendable {
    var load: @Sendable () -> HotkeySettings
    var save: @Sendable (HotkeySettings) -> Void
}

extension HotkeySettingsClient: DependencyKey {
    static var liveValue: HotkeySettingsClient {
        return HotkeySettingsClient(
            load: {
                let defaults = UserDefaults.standard
                let start = defaults.string(forKey: Keys.startShortcut) ?? HotkeySettings.default.startShortcut
                let capture = defaults.string(forKey: Keys.captureShortcut) ?? HotkeySettings.default.captureShortcut
                return HotkeySettings(startShortcut: start, captureShortcut: capture)
            },
            save: { settings in
                let defaults = UserDefaults.standard
                defaults.set(settings.startShortcut, forKey: Keys.startShortcut)
                defaults.set(settings.captureShortcut, forKey: Keys.captureShortcut)
            }
        )
    }

    static var testValue: HotkeySettingsClient {
        HotkeySettingsClient(
            load: { .default },
            save: { _ in }
        )
    }
}

extension DependencyValues {
    var hotkeySettingsClient: HotkeySettingsClient {
        get { self[HotkeySettingsClient.self] }
        set { self[HotkeySettingsClient.self] = newValue }
    }
}

private enum Keys {
    static let startShortcut = "orbit.hotkey.start"
    static let captureShortcut = "orbit.hotkey.capture"
}
