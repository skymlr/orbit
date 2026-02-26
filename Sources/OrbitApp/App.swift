import ComposableArchitecture
import Dependencies
import SwiftUI
import AppKit

private enum OrbitWindowID {
    static let capture = "capture-window"
    static let session = "session-window"
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
                .task {
                    store.send(.onLaunch)
                }
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Quick Capture", id: OrbitWindowID.capture) {
            if store.windowDestinations.contains(.captureWindow) {
                FloatingPaletteView(store: store)
                    .onDisappear {
                        store.send(.captureWindowClosed)
                    }
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 240)

        Window("Orbit Session", id: OrbitWindowID.session) {
            if store.windowDestinations.contains(.sessionWindow) {
                SessionWindowView(store: store)
                    .onDisappear {
                        store.send(.sessionWindowClosed)
                    }
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
            }
        }
        .defaultSize(width: 920, height: 680)

        Settings {
            OrbitSettingsView(store: store)
                .frame(minWidth: 820, minHeight: 620)
                .task {
                    store.send(.settingsRefreshTapped)
                }
        }
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
                syncWindows()
            }
            .onChange(of: store.windowDestinations) { _, _ in
                syncWindows()
            }
    }

    private func syncWindows() {
        syncWindow(id: OrbitWindowID.capture, isPresented: store.windowDestinations.contains(.captureWindow))
        syncWindow(id: OrbitWindowID.session, isPresented: store.windowDestinations.contains(.sessionWindow))
    }

    private func syncWindow(id: String, isPresented: Bool) {
        if isPresented {
            openWindow(id: id)
        } else {
            dismissWindow(id: id)
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
