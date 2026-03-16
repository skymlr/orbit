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
            background: .glass
        )

        client.save(expected)

        #expect(client.load() == expected)
    }
}
