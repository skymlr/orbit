import Dependencies
import Foundation

struct AppearanceSettingsClient: Sendable {
    var load: @Sendable () -> AppearanceSettings
    var save: @Sendable (AppearanceSettings) -> Void
}

extension AppearanceSettingsClient {
    static func live(userDefaults: UserDefaults = .standard) -> AppearanceSettingsClient {
        let storage = AppearanceUserDefaultsBox(userDefaults: userDefaults)
        return AppearanceSettingsClient(
            load: {
                let font = OrbitFontOption(
                    rawValue: storage.userDefaults.string(forKey: AppearanceSettingsKeys.font)
                        ?? AppearanceSettings.default.font.rawValue
                ) ?? .system
                let background = OrbitBackgroundOption(
                    rawValue: storage.userDefaults.string(forKey: AppearanceSettingsKeys.background)
                        ?? AppearanceSettings.default.background.rawValue
                ) ?? .orbit
                return AppearanceSettings(
                    font: font,
                    background: background
                )
            },
            save: { settings in
                storage.userDefaults.set(settings.font.rawValue, forKey: AppearanceSettingsKeys.font)
                storage.userDefaults.set(settings.background.rawValue, forKey: AppearanceSettingsKeys.background)
            }
        )
    }
}

extension AppearanceSettingsClient: DependencyKey {
    static var liveValue: AppearanceSettingsClient {
        .live()
    }

    static var testValue: AppearanceSettingsClient {
        AppearanceSettingsClient(
            load: { .default },
            save: { _ in }
        )
    }
}

extension DependencyValues {
    var appearanceSettingsClient: AppearanceSettingsClient {
        get { self[AppearanceSettingsClient.self] }
        set { self[AppearanceSettingsClient.self] = newValue }
    }
}

private enum AppearanceSettingsKeys {
    static let font = "orbit.appearance.font"
    static let background = "orbit.appearance.background"
}

private final class AppearanceUserDefaultsBox: @unchecked Sendable {
    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}
