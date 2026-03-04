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
                let nextPriority = defaults.string(forKey: Keys.captureNextPriorityShortcut)
                    ?? HotkeySettings.default.captureNextPriorityShortcut
                let themeModeRaw = defaults.string(forKey: Keys.themeMode)
                let themeMode = themeModeRaw.flatMap(OrbitThemeMode.init(rawValue:)) ?? .auto
                return HotkeySettings(
                    startShortcut: start,
                    captureShortcut: capture,
                    captureNextPriorityShortcut: nextPriority,
                    themeMode: themeMode
                )
            },
            save: { settings in
                let defaults = UserDefaults.standard
                defaults.set(settings.startShortcut, forKey: Keys.startShortcut)
                defaults.set(settings.captureShortcut, forKey: Keys.captureShortcut)
                defaults.set(settings.captureNextPriorityShortcut, forKey: Keys.captureNextPriorityShortcut)
                defaults.set(settings.themeMode.rawValue, forKey: Keys.themeMode)
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
    static let captureNextPriorityShortcut = "orbit.hotkey.capture.nextPriority"
    static let themeMode = "orbit.ui.themeMode"
}
