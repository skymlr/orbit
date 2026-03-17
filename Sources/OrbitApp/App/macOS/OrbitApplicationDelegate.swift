import Foundation

extension Notification.Name {
    static let orbitReopenRequested = Notification.Name("OrbitApp.reopenRequested")
}

#if os(macOS)
import AppKit

final class OrbitApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .orbitReopenRequested, object: nil)
        return true
    }
}
#endif
