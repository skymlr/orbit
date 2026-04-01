#if os(iOS)
import ComposableArchitecture
import SwiftUI

struct OrbitPhoneSearchRootView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    let onNavigateToHistoryDay: (Date) -> Void
    let onNavigateToHistorySession: (FocusSessionRecord) -> Void

    @StateObject private var searchModel = SessionUnifiedSearchModel()

    var body: some View {
        SessionUnifiedSearchContainer(store: store, model: searchModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                OrbitSpaceBackground(
                    style: store.appearance.background,
                    showsOrbitalLayer: store.appearance.showsOrbitalLayer
                )
            }
            .navigationTitle("Search")
            .orbitInlineNavigationTitleDisplayMode()
            .onAppear {
                configureSearchModel()
            }
            .onChange(of: store.settings.sessions) { _, _ in
                configureSearchModel()
            }
            .onChange(of: store.activeSession?.id) { _, _ in
                configureSearchModel()
            }
    }

    private func configureSearchModel() {
        searchModel.update(
            sessions: store.settings.sessions,
            excludingActiveSessionID: store.activeSession?.id,
            onGoToDayRequested: goToHistoryDay(_:),
            onGoToSessionRequested: goToHistorySession(_:),
            onExitRequested: clearSearch
        )
    }

    private func goToHistoryDay(_ day: Date) {
        searchModel.resetSearch()
        onNavigateToHistoryDay(day)
    }

    private func goToHistorySession(_ session: FocusSessionRecord) {
        searchModel.resetSearch()
        onNavigateToHistorySession(session)
    }

    private func clearSearch() {
        searchModel.resetSearch()
    }
}
#endif
