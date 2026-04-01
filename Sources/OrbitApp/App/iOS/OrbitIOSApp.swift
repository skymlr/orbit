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
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        Group {
            if isPhone {
                OrbitPhoneShellView(store: store)
            } else {
                OrbitIOSTabletRootView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AppLaunchCoordinator(store: store)
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
    }
}

private struct OrbitIOSTabletRootView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            WorkspaceView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            OrbitSpaceBackground()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .bottomBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .bottomBar)
        .sheet(
            isPresented: Binding(
                get: { store.presentation.isPreferencesPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.preferencesWindowClosed)
                    }
                }
            )
        ) {
            preferences
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
            quickCapture
        }
    }

    @ViewBuilder
    private var preferences: some View {
        NavigationStack {
            PreferencesView(store: store)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var quickCapture: some View {
        NavigationStack {
            QuickCaptureView(store: store)
                .orbitAppearance(store.appearance)
                .preferredColorScheme(.dark)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

#endif
