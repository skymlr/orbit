import ComposableArchitecture
import Foundation
import SwiftUI

struct SessionHistoryView: View {
    private enum Layout {
        static let contentMaxWidth: CGFloat = 700
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    let historyDayGroups: [HistoryDayGroup]
    let selectedHistoryDay: Date
    let selectedHistorySessionID: UUID?
    let onExitHistoryMode: () -> Void
    let onSelectHistorySession: (UUID) -> Void
    let onExportSession: (UUID) -> Void

    @State private var historyTaskFilter: HistoryTaskFilter = .completed

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Read-Only Session History")
                .font(.title3.weight(.bold))

            if let activeSession = store.activeSession {
                CurrentSessionHistoryBanner(
                    session: activeSession,
                    onBackToLiveSession: onExitHistoryMode
                )
            } else {
                noActiveSessionBanner
            }

            if historyDayGroups.isEmpty {
                historyContentUnavailableState(
                    message: "No completed sessions yet. End a session to build your history timeline."
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(SessionHistoryBrowserSupport.dayLabel(selectedHistoryDay))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.cyan)

                    Text("\(selectedHistoryDaySessions.count) \(selectedHistoryDaySessions.count == 1 ? "session" : "sessions")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if selectedHistoryDaySessions.isEmpty {
                    historyContentUnavailableState(
                        message: "No sessions on this day. Use the arrows or calendar to jump to a day with saved sessions."
                    )
                } else {
                    HistorySessionStripView(
                        sessions: selectedHistoryDaySessions,
                        selectedSessionID: selectedHistorySession?.id,
                        onSelect: onSelectHistorySession,
                        onRename: renameSession(sessionID:name:),
                        onDelete: deleteSession(sessionID:),
                        onExport: onExportSession
                    )

                    if let selectedHistorySession {
                        HistoryTaskListView(
                            session: selectedHistorySession,
                            filteredTasks: historyFilteredTasks,
                            historyTaskFilter: $historyTaskFilter
                        )
                    }
                }
            }
        }
        .frame(maxWidth: Layout.contentMaxWidth, alignment: .leading)
        .transition(.orbitMicro)
    }

    private var noActiveSessionBanner: some View {
        HStack(spacing: 10) {
            Text("No active session. You are browsing archived history.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Exit History") {
                onExitHistoryMode()
            }
            .buttonStyle(.orbitSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var selectedHistoryDaySessions: [FocusSessionRecord] {
        SessionHistoryBrowserSupport.sessions(on: selectedHistoryDay, from: historyDayGroups)
    }

    private var selectedHistorySession: FocusSessionRecord? {
        SessionHistoryBrowserSupport.resolveSelectedSession(
            id: selectedHistorySessionID,
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
    }

    private var historyFilteredTasks: [FocusTaskRecord] {
        guard let selectedHistorySession else { return [] }
        return SessionHistoryBrowserSupport.filteredTasks(
            for: selectedHistorySession,
            filter: historyTaskFilter
        )
    }

    private func historyContentUnavailableState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Sessions To Show")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func renameSession(sessionID: UUID, name: String) {
        store.send(.settingsRenameSessionTapped(sessionID, name))
    }

    private func deleteSession(sessionID: UUID) {
        store.send(.settingsDeleteSessionTapped(sessionID))
    }
}
