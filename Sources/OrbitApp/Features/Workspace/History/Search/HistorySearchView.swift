import SwiftUI

#if os(iOS)
import UIKit
#endif

struct HistorySearchView: View {
    private enum Layout {
        static let phoneContentInsets = EdgeInsets(top: 20, leading: 16, bottom: 28, trailing: 16)
        static let phoneRowSpacing: CGFloat = 14
    }

    @ObservedObject var model: HistorySearchPanelModel
    private let sessionsOverride: [FocusSessionRecord]?
    private let excludingActiveSessionIDOverride: UUID?

    init(
        model: HistorySearchPanelModel,
        sessions: [FocusSessionRecord]? = nil,
        excludingActiveSessionID: UUID? = nil
    ) {
        self.model = model
        self.sessionsOverride = sessions
        self.excludingActiveSessionIDOverride = excludingActiveSessionID
    }

    var body: some View {
        Group {
            if isPhone {
                phoneListContent
            } else {
                pageContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .orbitOnExitCommand {
            model.closeRequested()
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            OrbitSegmentedControl(
                "Task filter",
                selection: $model.filter,
                options: HistoryTaskFilter.searchTabs
            ) { filter in
                filter.title
            }

            content
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search History")
                .orbitFont(.title3, weight: .bold)

            Text("Find archived tasks by session name or task text using the toolbar search field.")
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if archivedSessionCount == 0 {
            emptyState(
                title: "No Archived Sessions Yet",
                message: "End a session to build your searchable history timeline."
            )
        } else if trimmedQuery.isEmpty {
            emptyState(
                title: "Start Typing To Search",
                message: "Use the toolbar search field to search archived session names and task text."
            )
        } else if searchResults.isEmpty {
            emptyState(
                title: "No Matches Found",
                message: "Try a different phrase or switch between All, Completed, Open, and Created Here."
            )
        } else {
            Group {
                if isPhone {
                    resultGroups
                } else {
                    ScrollView {
                        resultGroups
                    }
                    .scrollIndicators(.visible)
                }
            }
        }
    }

    private var resultGroups: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(searchResults) { dayGroup in
                dayGroupView(dayGroup)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var archivedSessionCount: Int {
        searchSessions.filter { session in
            session.endedAt != nil && session.id != excludedActiveSessionID
        }.count
    }

    private var trimmedQuery: String {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [HistorySearchDayGroup] {
        SessionHistorySearchSupport.dayGroups(
            from: searchSessions,
            excludingActiveSessionID: excludedActiveSessionID,
            query: model.query,
            filter: model.filter
        )
    }

    private var phoneListContent: some View {
        List {
            header
                .orbitPhoneListRow(insets: phoneListInsets(top: Layout.phoneContentInsets.top))

            OrbitSegmentedControl(
                "Task filter",
                selection: $model.filter,
                options: HistoryTaskFilter.searchTabs
            ) { filter in
                filter.title
            }
            .orbitPhoneListRow(insets: phoneListInsets())

            phoneContent
        }
        .orbitPhoneListStyle()
    }

    private func dayGroupView(_ dayGroup: HistorySearchDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    dayGroupSummary(dayGroup)

                    Spacer()

                    Button("Go to Day") {
                        model.goToDay(dayGroup.day)
                    }
                    .buttonStyle(.orbitSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    dayGroupSummary(dayGroup)

                    Button("Go to Day") {
                        model.goToDay(dayGroup.day)
                    }
                    .buttonStyle(.orbitSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(dayGroup.sessions) { sessionGroup in
                    sessionGroupView(sessionGroup)
                }
            }
        }
        .padding(16)
        .orbitSurfaceCard(fillStyle: .thinMaterial)
    }

    private func sessionGroupView(_ sessionGroup: HistorySearchSessionGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    sessionGroupSummary(sessionGroup)

                    Spacer()

                    Button("Go to Session") {
                        model.goToSession(sessionGroup.session)
                    }
                    .buttonStyle(.orbitSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    sessionGroupSummary(sessionGroup)

                    Button("Go to Session") {
                        model.goToSession(sessionGroup.session)
                    }
                    .buttonStyle(.orbitSecondary)
                }
            }

            if sessionGroup.tasks.isEmpty {
                Text("No tasks in the current filter for this matching session.")
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(sessionGroup.tasks) { task in
                        HistoryTaskRowView(task: task)
                    }
                }
            }
        }
        .padding(14)
        .orbitSurfaceCard(
            fillStyle: .ultraThinMaterial,
            cornerRadius: OrbitTheme.Radius.card,
            borderColor: OrbitTheme.Palette.glassBorder
        )
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .orbitFont(.title3, weight: .semibold)

            Text(message)
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .orbitSurfaceCard(fillStyle: .thinMaterial, borderColor: OrbitTheme.Palette.glassBorder)
    }

    private func dayGroupSummary(_ dayGroup: HistorySearchDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SessionHistoryBrowserSupport.dayLabel(dayGroup.day))
                .orbitFont(.headline, weight: .semibold)
                .foregroundStyle(OrbitTheme.Palette.orbitLine)

            Text(dayCountLabel(for: dayGroup))
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var phoneContent: some View {
        if archivedSessionCount == 0 {
            emptyState(
                title: "No Archived Sessions Yet",
                message: "End a session to build your searchable history timeline."
            )
            .orbitPhoneListRow(insets: phoneListInsets(bottom: Layout.phoneContentInsets.bottom))
        } else if trimmedQuery.isEmpty {
            emptyState(
                title: "Start Typing To Search",
                message: "Use the toolbar search field to search archived session names and task text."
            )
            .orbitPhoneListRow(insets: phoneListInsets(bottom: Layout.phoneContentInsets.bottom))
        } else if searchResults.isEmpty {
            emptyState(
                title: "No Matches Found",
                message: "Try a different phrase or switch between All, Completed, Open, and Created Here."
            )
            .orbitPhoneListRow(insets: phoneListInsets(bottom: Layout.phoneContentInsets.bottom))
        } else {
            let dayGroups = Array(searchResults.enumerated())

            ForEach(dayGroups, id: \.element.id) { dayEntry in
                let dayIndex = dayEntry.offset
                let dayGroup = dayEntry.element

                Section {
                    let sessionGroups = Array(dayGroup.sessions.enumerated())

                    ForEach(sessionGroups, id: \.element.id) { sessionEntry in
                        let sessionIndex = sessionEntry.offset
                        let sessionGroup = sessionEntry.element

                        sessionGroupView(sessionGroup)
                            .orbitPhoneListRow(
                                insets: phoneListInsets(
                                    bottom: isLastSearchRow(
                                        dayIndex: dayIndex,
                                        sessionIndex: sessionIndex,
                                        in: dayGroups
                                    )
                                    ? Layout.phoneContentInsets.bottom
                                    : Layout.phoneRowSpacing
                                )
                            )
                    }
                } header: {
                    phoneDayGroupHeader(dayGroup)
                        .textCase(nil)
                }
            }
        }
    }

    private func sessionGroupSummary(_ sessionGroup: HistorySearchSessionGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sessionGroup.session.name)
                .orbitFont(.subheadline, weight: .semibold)

            Text(sessionMetadata(for: sessionGroup))
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dayCountLabel(for dayGroup: HistorySearchDayGroup) -> String {
        let taskLabel = "\(dayGroup.totalTaskCount) \(dayGroup.totalTaskCount == 1 ? "task" : "tasks")"
        let sessionLabel = "\(dayGroup.sessions.count) \(dayGroup.sessions.count == 1 ? "session" : "sessions")"
        return "\(taskLabel) • \(sessionLabel)"
    }

    private func sessionMetadata(for sessionGroup: HistorySearchSessionGroup) -> String {
        let taskCount = sessionGroup.tasks.count
        let taskLabel = "\(taskCount) \(taskCount == 1 ? "task" : "tasks") shown"
        let startedAt = sessionGroup.session.startedAt.formatted(date: .omitted, time: .shortened)

        if let endedAt = sessionGroup.session.endedAt {
            let endedAtLabel = endedAt.formatted(date: .omitted, time: .shortened)
            return "Started \(startedAt) • Ended \(endedAtLabel) • \(taskLabel)"
        }

        return "Started \(startedAt) • \(taskLabel)"
    }

    private var isPhone: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }

    private var searchSessions: [FocusSessionRecord] {
        sessionsOverride ?? model.sessions
    }

    private var excludedActiveSessionID: UUID? {
        excludingActiveSessionIDOverride ?? model.excludingActiveSessionID
    }

    private func phoneDayGroupHeader(_ dayGroup: HistorySearchDayGroup) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                dayGroupSummary(dayGroup)

                Spacer()

                Button("Go to Day") {
                    model.goToDay(dayGroup.day)
                }
                .buttonStyle(.orbitSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                dayGroupSummary(dayGroup)

                Button("Go to Day") {
                    model.goToDay(dayGroup.day)
                }
                .buttonStyle(.orbitSecondary)
            }
        }
        .padding(.horizontal, Layout.phoneContentInsets.leading)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private func isLastSearchRow(
        dayIndex: Int,
        sessionIndex: Int,
        in dayGroups: [(offset: Int, element: HistorySearchDayGroup)]
    ) -> Bool {
        guard let lastDayIndex = dayGroups.indices.last else { return false }
        guard let lastSessionIndex = dayGroups[lastDayIndex].element.sessions.indices.last else { return false }
        return dayIndex == lastDayIndex && sessionIndex == lastSessionIndex
    }

    private func phoneListInsets(top: CGFloat = 0, bottom: CGFloat = Layout.phoneRowSpacing) -> EdgeInsets {
        EdgeInsets(
            top: top,
            leading: Layout.phoneContentInsets.leading,
            bottom: bottom,
            trailing: Layout.phoneContentInsets.trailing
        )
    }
}
