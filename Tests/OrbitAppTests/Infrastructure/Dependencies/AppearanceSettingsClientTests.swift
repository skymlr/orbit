import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct AppearanceSettingsClientTests {
    @Test
    func loadWithoutStoredValuesReturnsDefault() {
        let suiteName = "AppearanceSettingsClientTests.load.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let client = AppearanceSettingsClient.live(userDefaults: defaults)

        #expect(client.load() == .default)
    }

    @Test
    func saveRoundTripsStoredValues() {
        let suiteName = "AppearanceSettingsClientTests.roundTrip.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let client = AppearanceSettingsClient.live(userDefaults: defaults)
        let expected = AppearanceSettings(
            font: .sourceSerif4,
            background: .glass,
            showsOrbitalLayer: true
        )

        client.save(expected)

        #expect(client.load() == expected)
    }

    @Test
    func loadLegacySpaceBlueBackgroundEnablesOrbitalLayer() {
        let suiteName = "AppearanceSettingsClientTests.legacyOrbit.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(OrbitFontOption.system.rawValue, forKey: "orbit.appearance.font")
        defaults.set("orbit", forKey: "orbit.appearance.background")

        let client = AppearanceSettingsClient.live(userDefaults: defaults)

        #expect(
            client.load()
            == AppearanceSettings(font: .system, background: .spaceBlue, showsOrbitalLayer: true)
        )
    }

    @Test
    func loadLegacyPlainBackgroundDisablesOrbitalLayer() {
        let suiteName = "AppearanceSettingsClientTests.legacyPlain.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(OrbitFontOption.geist.rawValue, forKey: "orbit.appearance.font")
        defaults.set("blue", forKey: "orbit.appearance.background")

        let client = AppearanceSettingsClient.live(userDefaults: defaults)

        #expect(
            client.load()
            == AppearanceSettings(font: .geist, background: .skyBlue, showsOrbitalLayer: false)
        )
    }
}
