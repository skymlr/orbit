import AppKit
import Foundation

extension Notification.Name {
    static let orbitReopenRequested = Notification.Name("OrbitApp.reopenRequested")
}

final class OrbitApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .orbitReopenRequested, object: nil)
        return true
    }
}
