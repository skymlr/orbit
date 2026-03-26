import ComposableArchitecture
import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

struct SessionHistoryView: View {
    private enum Layout {
        static let contentMaxWidth: CGFloat = 700
        static let phoneContentInsets = EdgeInsets(top: 20, leading: 16, bottom: 28, trailing: 16)
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.orbitAdaptiveLayout) private var layout
    let historyDayGroups: [HistoryDayGroup]
    let selectedHistoryDay: Date
    let selectedHistorySessionID: UUID?
    let onExitHistoryMode: () -> Void
    let onSelectHistorySession: (UUID) -> Void
    let onExportSession: (UUID) -> Void

    @State private var historyTaskFilter: HistoryTaskFilter = .completed

    var body: some View {
        Group {
            if isPhone {
                ScrollView {
                    pageContent
                        .padding(Layout.phoneContentInsets)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
            } else {
                pageContent
            }
        }
        .frame(
            maxWidth: layout.isCompact ? .infinity : Layout.contentMaxWidth,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .transition(.orbitMicro)
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !layout.isCompact {
                Text("Read-Only Session History")
                    .orbitFont(.title3, weight: .bold)
            }

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
                selectedDaySummaryCard

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
    }

    private var selectedDaySummaryCard: some View {
        OrbitIndexCard(
            systemImage: "calendar",
            title: SessionHistoryBrowserSupport.dayLabel(selectedHistoryDay),
            subtitle: selectedDaySummary,
            tint: .cyan,
            showsChevron: false
        )
    }

    private var noActiveSessionBanner: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Text("No active session. You are browsing archived history.")
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Exit History") {
                    onExitHistoryMode()
                }
                .buttonStyle(.orbitSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("No active session. You are browsing archived history.")
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)

                Button("Exit History") {
                    onExitHistoryMode()
                }
                .buttonStyle(.orbitSecondary)
            }
        }
        .padding(12)
        .orbitSurfaceCard()
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
                .orbitFont(.title3, weight: .semibold)

            Text(message)
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .orbitSurfaceCard()
    }

    private var selectedDaySummary: String {
        let sessionCount = selectedHistoryDaySessions.count
        let taskCount = selectedHistoryDaySessions.reduce(into: 0) { count, session in
            count += session.tasks.count
        }
        let sessionLabel = "\(sessionCount) \(sessionCount == 1 ? "session" : "sessions")"
        let taskLabel = "\(taskCount) \(taskCount == 1 ? "task" : "tasks")"
        return "\(sessionLabel) • \(taskLabel)"
    }

    private func renameSession(sessionID: UUID, name: String) {
        store.send(.settingsRenameSessionTapped(sessionID, name))
    }

    private func deleteSession(sessionID: UUID) {
        store.send(.settingsDeleteSessionTapped(sessionID))
    }

    private var isPhone: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }
}
