import Dependencies
import Foundation

struct CloudSyncSettingsClient: Sendable {
    var load: @Sendable () -> Bool
    var save: @Sendable (Bool) -> Void
}

extension CloudSyncSettingsClient {
    static func live(userDefaults: UserDefaults = .standard) -> CloudSyncSettingsClient {
        let storage = CloudSyncSettingsUserDefaultsBox(userDefaults: userDefaults)
        return CloudSyncSettingsClient(
            load: {
                storage.userDefaults.bool(forKey: Keys.enabled)
            },
            save: { isEnabled in
                storage.userDefaults.set(isEnabled, forKey: Keys.enabled)
            }
        )
    }
}

extension CloudSyncSettingsClient: DependencyKey {
    static var liveValue: CloudSyncSettingsClient {
        .live()
    }

    static var testValue: CloudSyncSettingsClient {
        CloudSyncSettingsClient(
            load: { false },
            save: { _ in }
        )
    }
}

extension DependencyValues {
    var cloudSyncSettingsClient: CloudSyncSettingsClient {
        get { self[CloudSyncSettingsClient.self] }
        set { self[CloudSyncSettingsClient.self] = newValue }
    }
}

private enum Keys {
    static let enabled = "orbit.cloudSyncEnabled"
}

private final class CloudSyncSettingsUserDefaultsBox: @unchecked Sendable {
    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}
