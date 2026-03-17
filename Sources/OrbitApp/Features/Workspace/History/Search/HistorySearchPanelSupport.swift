import Foundation
import SwiftUI

struct HistorySearchPanelConfiguration {
    let sessions: [FocusSessionRecord]
    let excludingActiveSessionID: UUID?
    let appearance: AppearanceSettings
    let onGoToDay: (Date) -> Void
    let onGoToSession: (Date, UUID) -> Void
    let onClose: () -> Void
}

@MainActor
final class HistorySearchPanelModel: ObservableObject {
    @Published var query = ""
    @Published var filter: HistoryTaskFilter = .all
    @Published var sessions: [FocusSessionRecord] = []
    @Published var excludingActiveSessionID: UUID?
    @Published var appearance: AppearanceSettings = .default
    var onGoToDayRequested: (Date) -> Void = { _ in }
    var onGoToSessionRequested: (FocusSessionRecord) -> Void = { _ in }
    var onCloseRequested: () -> Void = {}

    func resetSearch() {
        query = ""
        filter = .all
    }

    func goToDay(_ day: Date) {
        onGoToDayRequested(day)
    }

    func goToSession(_ session: FocusSessionRecord) {
        onGoToSessionRequested(session)
    }

    func closeRequested() {
        onCloseRequested()
    }
}

struct HistorySearchPanelRootView: View {
    @ObservedObject var model: HistorySearchPanelModel

    var body: some View {
        ZStack {
            OrbitSpaceBackground()

            HistorySearchView(model: model)
                .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .orbitAppearance(model.appearance)
        .preferredColorScheme(.dark)
    }
}
