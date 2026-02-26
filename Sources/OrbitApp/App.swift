import ComposableArchitecture
import SwiftUI

@main
struct OrbitMenuBarApp: App {
    let store: StoreOf<AppFeature>
    @State private var paletteController = FloatingPalettePanelController()

    init() {
        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .task {
                    store.send(.onLaunch)
                }
                .background {
                    FloatingPalettePresenter(store: store, controller: paletteController)
                }
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .frame(width: 360, height: 180)
        }
    }
}

private struct MenuBarLabelView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Image(systemName: store.currentMode.config.symbolName)
            .accessibilityLabel("Orbit \(store.currentMode.config.displayName) Mode")
    }
}

private struct FloatingPalettePresenter: View {
    let store: StoreOf<AppFeature>
    let controller: FloatingPalettePanelController

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: store.floatingPalette != nil) { _, isPresented in
                if isPresented {
                    controller.show(store: store)
                } else {
                    controller.hide()
                }
            }
            .onChange(of: store.floatingPalette?.isPinnedToEdge ?? false) { _, pinned in
                if pinned {
                    controller.pinToEdge()
                }
            }
    }
}

private struct PreferencesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Orbit")
                .font(.title2.bold())
            Text("Cmd+Shift+O toggles quick capture.")
                .foregroundStyle(.secondary)
            Text("Sessions are saved under ~/Library/Application Support/Orbit/sessions.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
