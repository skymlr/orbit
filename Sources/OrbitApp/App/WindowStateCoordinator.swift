import AppKit
import ComposableArchitecture
import SwiftUI

enum OrbitWindowID {
    static let workspace = "workspace-window"
}

struct WindowStateCoordinator: View {
    let store: StoreOf<AppFeature>

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                syncWindows(from: [], to: store.windowDestinations)
            }
            .onChange(of: store.windowDestinations) { oldValue, newValue in
                syncWindows(from: oldValue, to: newValue)
            }
            .onChange(of: store.workspaceWindowFocusRequest) { _, _ in
                guard store.windowDestinations.contains(.workspaceWindow) else {
                    return
                }
                openWindow(id: OrbitWindowID.workspace)
                bringWorkspaceWindowToFront()
            }
            .onChange(of: store.captureWindowFocusRequest) { _, _ in
                guard store.windowDestinations.contains(.captureWindow) else {
                    return
                }
                QuickCapturePanelController.shared.present(store: store)
            }
    }

    private func syncWindows(from oldValue: Set<AppFeature.WindowDestination>, to newValue: Set<AppFeature.WindowDestination>) {
        let removed = oldValue.subtracting(newValue)
        let added = newValue.subtracting(oldValue)

        if removed.contains(.captureWindow) {
            QuickCapturePanelController.shared.dismiss()
        }
        if removed.contains(.workspaceWindow) {
            dismissWindow(id: OrbitWindowID.workspace)
        }

        if added.contains(.workspaceWindow) {
            openWindow(id: OrbitWindowID.workspace)
            bringWorkspaceWindowToFront()
        }
        if added.contains(.captureWindow) {
            QuickCapturePanelController.shared.present(store: store)
        }
    }

    private func bringWorkspaceWindowToFront() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Orbit: A Focus Manager" }) else {
                return
            }
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
}
