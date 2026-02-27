import ComposableArchitecture
import Dependencies
import SwiftUI
import AppKit

private enum OrbitWindowID {
    static let session = "session-window"
    static let endSession = "end-session-window"
    static let settings = "settings-window"
}

@main
struct OrbitMenuBarApp: App {
    let store: StoreOf<AppFeature>

    init() {
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }

        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }

        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Orbit Session", id: OrbitWindowID.session) {
            if store.windowDestinations.contains(.sessionWindow) {
                SessionView(store: store)
                    .onDisappear {
                        store.send(.sessionWindowClosed)
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
                    onConfirm: { name, categoryID in
                        store.send(.endSessionConfirmTapped(name: name, categoryID: categoryID))
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
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 260)

        Window("Orbit Settings", id: OrbitWindowID.settings) {
            OrbitSettingsView(store: store)
                .frame(minWidth: 820, minHeight: 620)
                .task {
                    store.send(.settingsRefreshTapped)
                }
        }
        .defaultSize(width: 980, height: 700)
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
    }

    private func syncWindows(from oldValue: Set<AppFeature.WindowDestination>, to newValue: Set<AppFeature.WindowDestination>) {
        let removed = oldValue.subtracting(newValue)
        let added = newValue.subtracting(oldValue)

        if removed.contains(.captureWindow) {
            QuickCapturePanelController.shared.dismiss()
        }
        if removed.contains(.sessionWindow) {
            dismissWindow(id: OrbitWindowID.session)
        }
        if removed.contains(.endSessionWindow) {
            dismissWindow(id: OrbitWindowID.endSession)
        }

        if added.contains(.sessionWindow) {
            openWindow(id: OrbitWindowID.session)
            bringSessionWindowToFront()
        }
        if added.contains(.captureWindow) {
            QuickCapturePanelController.shared.present(store: store)
        }
        if added.contains(.endSessionWindow) {
            openWindow(id: OrbitWindowID.endSession)
            bringEndSessionWindowToFront()
        }
    }

    private func bringSessionWindowToFront() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Orbit Session" }) else {
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
    }
}

private struct AppLaunchCoordinator: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                store.send(.onLaunch)
            }
    }
}
