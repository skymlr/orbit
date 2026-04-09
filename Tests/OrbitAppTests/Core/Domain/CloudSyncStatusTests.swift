import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct CloudSyncStatusTests {
    @Test
    func statusesMapToSettingsAndSessionCopy() {
        let cases: [(SyncStatus, session: String, settings: String, retry: Bool)] = [
            (.off, "Off", "Sync is off", false),
            (.starting, "Starting", "Starting iCloud sync", false),
            (.syncing, "Syncing", "Sync in progress", false),
            (.enabled, "Synced", "iCloud sync is on", false),
            (.retryNeeded("Needs attention"), "Needs Attention", "Needs attention", true),
        ]

        for testCase in cases {
            #expect(testCase.0.sessionLabel == testCase.session)
            #expect(testCase.0.settingsTitle == testCase.settings)
            #expect(testCase.0.isRetryAvailable == testCase.retry)
            #expect(!testCase.0.sessionMessage.isEmpty)
            #expect(!testCase.0.settingsMessage.isEmpty)
        }
    }
}
