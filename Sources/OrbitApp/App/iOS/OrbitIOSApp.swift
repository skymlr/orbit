#if os(iOS)
import ComposableArchitecture
import Dependencies
import SwiftUI

@main
struct OrbitIOSApp: App {
    let store: StoreOf<AppFeature>

    init() {
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }

        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }

        OrbitFontRegistry.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            OrbitIOSRootView(store: store)
                .orbitAppearance(store.appearance)
                .preferredColorScheme(.dark)
        }
    }
}

private struct OrbitIOSRootView: View {
    private enum Tab: Hashable {
        case workspace
        case settings
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var selectedTab: Tab = .workspace

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkspaceView(store: store)
                .tabItem {
                    Label("Workspace", systemImage: "square.grid.2x2.fill")
                }
                .tag(Tab.workspace)

            PreferencesView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .background {
            AppLaunchCoordinator(store: store)
        }
        .sheet(
            isPresented: Binding(
                get: { store.presentation.isCapturePresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.captureWindowClosed)
                    }
                }
            )
        ) {
            NavigationStack {
                QuickCaptureView(store: store)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                store.send(.captureWindowClosed)
                            }
                        }
                    }
                    .orbitAppearance(store.appearance)
                    .preferredColorScheme(.dark)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(
            item: Binding(
                get: { store.presentation.sharedExport },
                set: { sharedExport in
                    if sharedExport == nil {
                        store.send(.sharedExportDismissed)
                    }
                }
            )
        ) { sharedExport in
            OrbitShareSheet(activityItems: sharedExport.urls)
        }
        .onChange(of: store.presentation.workspacePresentationRequest) { _, _ in
            selectedTab = .workspace
        }
    }
}
#endif
