#if os(iOS)
import ComposableArchitecture
import SwiftUI

struct OrbitPhoneHistorySearchRootView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    let onNavigateToHistoryDay: (Date) -> Void
    let onNavigateToHistorySession: (FocusSessionRecord) -> Void

    @StateObject private var historySearchModel = HistorySearchPanelModel()

    var body: some View {
        HistorySearchView(
            model: historySearchModel,
            sessions: store.settings.sessions,
            excludingActiveSessionID: store.activeSession?.id
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            OrbitSpaceBackground(
                style: store.appearance.background,
                showsOrbitalLayer: store.appearance.showsOrbitalLayer
            )
        }
        .navigationTitle("Search")
        .orbitInlineNavigationTitleDisplayMode()
        .searchable(text: $historySearchModel.query, placement: .toolbar, prompt: "Search history")
        .task(id: store.activeSession?.id) {
            configureSearchModel()
        }
        .onChange(of: store.appearance) { _, newAppearance in
            historySearchModel.appearance = newAppearance
        }
        .onAppear {
            configureSearchModel()
        }
    }

    private func configureSearchModel() {
        historySearchModel.sessions = store.settings.sessions
        historySearchModel.excludingActiveSessionID = store.activeSession?.id
        historySearchModel.appearance = store.appearance
        historySearchModel.onGoToDayRequested = goToHistoryDay(_:)
        historySearchModel.onGoToSessionRequested = goToHistorySession(_:)
        historySearchModel.onCloseRequested = clearSearch
    }

    private func goToHistoryDay(_ day: Date) {
        historySearchModel.resetSearch()
        onNavigateToHistoryDay(day)
    }

    private func goToHistorySession(_ session: FocusSessionRecord) {
        historySearchModel.resetSearch()
        onNavigateToHistorySession(session)
    }

    private func clearSearch() {
        historySearchModel.resetSearch()
    }
}
#endif
