#if os(iOS)
import ComposableArchitecture
import SwiftUI
import UIKit

struct OrbitPhoneShellView: View {
    private enum RootTab: String, CaseIterable, Identifiable {
        case session
        case history
        case search
        case settings

        var id: Self { self }

        var title: String {
            switch self {
            case .session:
                return "Session"
            case .history:
                return "History"
            case .search:
                return "Search"
            case .settings:
                return "Settings"
            }
        }

        var symbolName: String {
            switch self {
            case .session:
                return "checklist"
            case .history:
                return "clock.arrow.circlepath"
            case .search:
                return "magnifyingglass"
            case .settings:
                return "gearshape"
            }
        }
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var selectedTab: RootTab = .session
    @State private var selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: Date())
    @State private var selectedHistorySessionID: UUID?

    var body: some View {
        ZStack {
            phoneBackground
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                Tab(
                    RootTab.session.title,
                    systemImage: RootTab.session.symbolName,
                    value: RootTab.session
                ) {
                    sessionRoot
                }

                Tab(
                    RootTab.history.title,
                    systemImage: RootTab.history.symbolName,
                    value: RootTab.history
                ) {
                    historyRoot
                }

                Tab(
                    RootTab.search.title,
                    systemImage: RootTab.search.symbolName,
                    value: RootTab.search,
                    role: .search
                ) {
                    searchRoot
                }

                Tab(
                    RootTab.settings.title,
                    systemImage: RootTab.settings.symbolName,
                    value: RootTab.settings
                ) {
                    settingsRoot
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            toastInset
        }
        .sheet(isPresented: capturePresentationBinding) {
            quickCapture
        }
        .onChange(of: store.presentation.workspacePresentationRequest) { oldValue, newValue in
            if newValue != oldValue {
                selectedTab = .session
            }
        }
        .onChange(of: store.presentation.preferencesPresentationRequest) { oldValue, newValue in
            guard newValue != oldValue else { return }
            selectedTab = .settings
            if store.presentation.isPreferencesPresented {
                store.send(.preferencesWindowClosed)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: store.toast?.id)
    }

    private var sessionRoot: some View {
        phoneNavigationStack {
            SessionLiveView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background {
                    OrbitSpaceBackground(
                        style: store.appearance.background,
                        showsOrbitalLayer: store.appearance.showsOrbitalLayer
                    )
                }
        }
    }

    private var historyRoot: some View {
        phoneNavigationStack {
            OrbitPhoneHistoryRootView(
                store: store,
                selectedHistoryDay: $selectedHistoryDay,
                selectedHistorySessionID: $selectedHistorySessionID,
                onBackToSession: backToSessionButtonTapped
            )
        }
    }

    private var searchRoot: some View {
        phoneNavigationStack {
            OrbitPhoneSearchRootView(
                store: store,
                onNavigateToHistoryDay: navigateToHistoryDayFromSearch(_:),
                onNavigateToHistorySession: navigateToHistorySessionFromSearch(_:)
            )
        }
    }

    private var settingsRoot: some View {
        phoneNavigationStack {
            PreferencesView(store: store)
        }
    }

    private var phoneBackground: some View {
        OrbitSpaceBackground(
            style: store.appearance.background,
            showsOrbitalLayer: store.appearance.showsOrbitalLayer
        )
    }

    private func phoneNavigationStack<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background {
            phoneBackground
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var toastInset: some View {
        if let toast = store.toast {
            OrbitToastView(
                toast: toast,
                onDismiss: dismissToastButtonTapped
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.orbitToastNotification.combined(with: .opacity))
        }
    }

    private var capturePresentationBinding: Binding<Bool> {
        Binding(
            get: { store.presentation.isCapturePresented },
            set: { isPresented in
                if !isPresented {
                    store.send(.captureWindowClosed)
                }
            }
        )
    }

    @ViewBuilder
    private var quickCapture: some View {
        NavigationStack {
            QuickCaptureView(store: store)
                .orbitAppearance(store.appearance)
                .preferredColorScheme(.dark)
        }
        .toolbar(.hidden, for: .navigationBar)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func backToSessionButtonTapped() {
        selectedTab = .session
    }

    private func dismissToastButtonTapped() {
        store.send(.toastDismissTapped)
    }

    private var historyDayGroups: [HistoryDayGroup] {
        SessionHistoryBrowserSupport.dayGroups(
            from: store.settings.sessions,
            excludingActiveSessionID: store.activeSession?.id
        )
    }

    private func navigateToHistoryDayFromSearch(_ day: Date) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
        selectedTab = .history
    }

    private func navigateToHistorySessionFromSearch(_ session: FocusSessionRecord) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: session.startedAt)
        selectedHistorySessionID = session.id
        selectedTab = .history
    }
}
#endif
