import Dependencies
import Foundation
import SQLiteData

struct CloudSyncClient: Sendable {
    var start: @Sendable () async throws -> Void
    var stop: @Sendable () -> Void
    var fetchChanges: @Sendable () async throws -> Void
    var state: @Sendable () -> CloudSyncEngineState
}

extension CloudSyncClient: DependencyKey {
    static var liveValue: CloudSyncClient {
#if LOCAL_UNSIGNED
        CloudSyncClient(
            start: {},
            stop: {},
            fetchChanges: {},
            state: {
                CloudSyncEngineState(
                    isRunning: false,
                    isSynchronizing: false
                )
            }
        )
#else
        CloudSyncClient(
            start: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                try await syncEngine.start()
            },
            stop: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                syncEngine.stop()
            },
            fetchChanges: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                try await syncEngine.fetchChanges()
            },
            state: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                return CloudSyncEngineState(
                    isRunning: syncEngine.isRunning,
                    isSynchronizing: syncEngine.isSynchronizing
                )
            }
        )
#endif
    }

    static var testValue: CloudSyncClient {
        CloudSyncClient(
            start: {},
            stop: {},
            fetchChanges: {},
            state: {
                CloudSyncEngineState(
                    isRunning: false,
                    isSynchronizing: false
                )
            }
        )
    }
}

extension DependencyValues {
    var cloudSyncClient: CloudSyncClient {
        get { self[CloudSyncClient.self] }
        set { self[CloudSyncClient.self] = newValue }
    }
}
