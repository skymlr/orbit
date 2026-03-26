#if os(macOS)
import AppKit
import ComposableArchitecture
import Dependencies
import SwiftUI

@main
struct OrbitMacApp: App {
    private enum Layout {
        static let workspaceMinWidth: CGFloat = 820
        static let workspaceDefaultSize = CGSize(width: 820, height: 680)
        static let settingsDefaultSize = CGSize(width: 650, height: 500)
    }

    @NSApplicationDelegateAdaptor(OrbitApplicationDelegate.self) private var appDelegate
    let store: StoreOf<AppFeature>

    init() {
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }

        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }

        OrbitFontRegistry.registerBundledFonts()
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .orbitAppearance(store.appearance)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Orbit: A Focus Manager", id: OrbitWindowID.workspace) {
            Group {
                if store.presentation.isWorkspacePresented {
                    WorkspaceView(store: store)
                        .orbitAppearance(store.appearance)
                        .frame(minWidth: Layout.workspaceMinWidth)
                        .onDisappear {
                            store.send(.workspaceWindowClosed)
                        }
                } else {
                    Color.clear
                        .frame(width: 1, height: 1)
                }
            }
            .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(
            width: Layout.workspaceDefaultSize.width,
            height: Layout.workspaceDefaultSize.height
        )
        .windowResizability(.contentMinSize)

        Settings {
            PreferencesView(store: store)
                .orbitAppearance(store.appearance)
                .preferredColorScheme(.dark)
        }
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(
            width: Layout.settingsDefaultSize.width,
            height: Layout.settingsDefaultSize.height
        )
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
#endif
