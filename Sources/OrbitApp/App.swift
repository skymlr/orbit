import ComposableArchitecture
import Dependencies
import SwiftUI
import AppKit

private enum OrbitWindowID {
    static let workspace = "workspace-window"
    static let endSession = "end-session-window"
}

private extension Notification.Name {
    static let orbitReopenRequested = Notification.Name("OrbitApp.reopenRequested")
}

private final class OrbitApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .orbitReopenRequested, object: nil)
        return true
    }
}

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(OrbitApplicationDelegate.self) private var appDelegate
    let store: StoreOf<AppFeature>

    init() {
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }

        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }

        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Orbit: A Focus Manager", id: OrbitWindowID.workspace) {
            if store.windowDestinations.contains(.workspaceWindow) {
                WorkspaceView(store: store)
                    .onDisappear {
                        store.send(.workspaceWindowClosed)
                    }
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
            }
        }
        .defaultSize(width: 920, height: 680)

        Window("End Session", id: OrbitWindowID.endSession) {
            if store.windowDestinations.contains(.endSessionWindow), let draft = store.endSessionDraft {
                EndSessionPromptView(
                    draft: draft,
                    onConfirm: { name in
                        store.send(.endSessionConfirmTapped(name: name))
                    },
                    onCancel: {
                        store.send(.endSessionCancelTapped)
                    }
                )
                .onDisappear {
                    store.send(.endSessionWindowClosed)
                }
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
            }
        }
        .defaultSize(width: 400, height: 260)

    }
}

private struct MenuBarLabelView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Image(systemName: store.activeSession == nil ? "circle" : "circle.fill")
            .accessibilityLabel(store.activeSession == nil ? "Orbit no active focus session" : "Orbit active focus session")
            .background {
                WindowStateCoordinator(store: store)
            }
            .background {
                AppLifecycleCoordinator(store: store)
            }
            .background {
                AppLaunchCoordinator(store: store)
            }
    }
}

private struct WindowStateCoordinator: View {
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
        if removed.contains(.endSessionWindow) {
            dismissWindow(id: OrbitWindowID.endSession)
        }

        if added.contains(.workspaceWindow) {
            openWindow(id: OrbitWindowID.workspace)
            bringWorkspaceWindowToFront()
        }
        if added.contains(.captureWindow) {
            QuickCapturePanelController.shared.present(store: store)
        }
        if added.contains(.endSessionWindow) {
            openWindow(id: OrbitWindowID.endSession)
            bringEndSessionWindowToFront()
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

    private func bringEndSessionWindowToFront() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "End Session" }) else {
                return
            }
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
}

private struct AppLifecycleCoordinator: View {
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

private struct AppLaunchCoordinator: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                store.send(.onLaunch)
                store.send(.openWorkspaceTapped)
            }
    }
}
