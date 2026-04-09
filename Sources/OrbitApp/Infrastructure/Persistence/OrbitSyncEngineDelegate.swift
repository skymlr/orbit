import CloudKit
import Foundation
import SQLiteData

@available(iOS 17, macOS 14, *)
final class OrbitSyncEngineDelegate: SyncEngineDelegate, @unchecked Sendable {
    func syncEngine(
        _ syncEngine: SQLiteData.SyncEngine,
        accountChanged changeType: CKSyncEngine.Event.AccountChange.ChangeType
    ) async {
        switch changeType {
        case .signIn:
            break
        case .signOut, .switchAccounts:
            syncEngine.stop()
        @unknown default:
            syncEngine.stop()
        }
    }
}
