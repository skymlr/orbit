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
                let storedBackgroundValue = storage.userDefaults.string(forKey: AppearanceSettingsKeys.background)
                let font = OrbitFontOption(
                    rawValue: storage.userDefaults.string(forKey: AppearanceSettingsKeys.font)
                        ?? AppearanceSettings.default.font.rawValue
                ) ?? .system
                let background = OrbitBackgroundOption(
                    rawValue: storedBackgroundValue ?? AppearanceSettings.default.background.rawValue
                ) ?? .spaceBlue
                let showsOrbitalLayer = orbitalLayerValue(
                    from: storage.userDefaults.object(forKey: AppearanceSettingsKeys.orbitalLayer),
                    storedBackgroundValue: storedBackgroundValue
                )
                return AppearanceSettings(
                    font: font,
                    background: background,
                    showsOrbitalLayer: showsOrbitalLayer
                )
            },
            save: { settings in
                storage.userDefaults.set(settings.font.rawValue, forKey: AppearanceSettingsKeys.font)
                storage.userDefaults.set(settings.background.rawValue, forKey: AppearanceSettingsKeys.background)
                storage.userDefaults.set(settings.showsOrbitalLayer, forKey: AppearanceSettingsKeys.orbitalLayer)
            }
        )
    }

    private static func orbitalLayerValue(
        from storedValue: Any?,
        storedBackgroundValue: String?
    ) -> Bool {
        if let storedValue = storedValue as? Bool {
            return storedValue
        }

        guard let storedBackgroundValue else {
            return AppearanceSettings.default.showsOrbitalLayer
        }

        switch storedBackgroundValue {
        case OrbitBackgroundOption.spaceBlue.rawValue:
            return true
        default:
            return false
        }
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
    static let orbitalLayer = "orbit.appearance.orbitalLayer"
}

private final class AppearanceUserDefaultsBox: @unchecked Sendable {
    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}
