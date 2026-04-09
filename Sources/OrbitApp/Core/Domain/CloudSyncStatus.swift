import Foundation

enum SyncStatus: Equatable, Sendable {
    case off
    case starting
    case syncing
    case enabled
    case retryNeeded(String)
}

struct CloudSyncEngineState: Equatable, Sendable {
    var isRunning: Bool
    var isSynchronizing: Bool
}

extension SyncStatus {
    var sessionLabel: String {
        switch self {
        case .off:
            return "Off"
        case .starting:
            return "Starting"
        case .syncing:
            return "Syncing"
        case .enabled:
            return "Synced"
        case .retryNeeded:
            return "Needs Attention"
        }
    }

    var settingsTitle: String {
        switch self {
        case .off:
            return "Sync is off"
        case .starting:
            return "Starting iCloud sync"
        case .syncing:
            return "Sync in progress"
        case .enabled:
            return "iCloud sync is on"
        case let .retryNeeded(message):
            return message
        }
    }

    var settingsMessage: String {
        switch self {
        case .off:
            return "Orbit will stay local-only until you enable iCloud sync."
        case .starting:
            return "Orbit is connecting to iCloud and preparing your local database for sync."
        case .syncing:
            return "Orbit is exchanging session, task, and category updates with iCloud."
        case .enabled:
            return "Sessions, tasks, and categories are syncing through iCloud. Appearance and hotkeys stay local to this device."
        case .retryNeeded:
            return "Local Orbit data is still available on this device. Retry after confirming iCloud is available for Orbit."
        }
    }

    var sessionMessage: String {
        switch self {
        case .off:
            return "Sync is off for this device."
        case .starting:
            return "Sync is starting."
        case .syncing:
            return "Sync is in progress."
        case .enabled:
            return "iCloud sync is up to date."
        case .retryNeeded:
            return "Sync needs attention. Local session data stays available."
        }
    }

    var isRetryAvailable: Bool {
        if case .retryNeeded = self {
            return true
        }
        return false
    }
}
