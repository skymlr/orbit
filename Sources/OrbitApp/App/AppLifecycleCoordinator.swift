import AppKit
import ComposableArchitecture
import SwiftUI

struct AppLifecycleCoordinator: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                store.send(.appWillTerminate)
            }
            .onReceive(NotificationCenter.default.publisher(for: .orbitReopenRequested)) { _ in
                store.send(.openWorkspaceTapped)
            }
    }
}
