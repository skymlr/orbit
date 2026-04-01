#if os(iOS)
import ComposableArchitecture
import SwiftUI

struct OrbitPhoneSearchRootView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    let onNavigateToHistoryDay: (Date) -> Void
    let onNavigateToHistorySession: (FocusSessionRecord) -> Void

    @StateObject private var searchModel = HistorySearchPanelModel()

    var body: some View {
        OrbitPhoneUnifiedSearchView(
            store: store,
            model: searchModel
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
        .searchable(text: $searchModel.query, placement: .toolbar, prompt: "Search tasks and history")
        .onAppear {
            configureSearchModel()
        }
        .onChange(of: store.settings.sessions) { _, _ in
            configureSearchModel()
        }
        .onChange(of: store.activeSession?.id) { _, _ in
            configureSearchModel()
        }
        .onChange(of: store.appearance) { _, newAppearance in
            searchModel.appearance = newAppearance
        }
    }

    private func configureSearchModel() {
        searchModel.sessions = store.settings.sessions
        searchModel.excludingActiveSessionID = store.activeSession?.id
        searchModel.appearance = store.appearance
        searchModel.onGoToDayRequested = goToHistoryDay(_:)
        searchModel.onGoToSessionRequested = goToHistorySession(_:)
        searchModel.onCloseRequested = clearSearch
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

private struct OrbitPhoneUnifiedSearchView: View {
    private enum Layout {
        static let phoneContentInsets = EdgeInsets(top: 20, leading: 16, bottom: 28, trailing: 16)
        static let phoneRowSpacing: CGFloat = 14
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @ObservedObject var model: HistorySearchPanelModel

    var body: some View {
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

            if let liveSearchResult {
                Section {
                    liveSectionContent(liveSearchResult)
                } header: {
                    liveSectionHeader(liveSearchResult)
                        .textCase(nil)
                }
            }

            archivedSectionIntro
                .orbitPhoneListRow(insets: phoneListInsets())

            archivedSectionContent
        }
        .orbitPhoneListStyle()
        .orbitOnExitCommand {
            model.closeRequested()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search Tasks and History")
                .orbitFont(.title3, weight: .bold)

            Text(headerMessage)
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func liveSectionContent(_ result: LiveTaskSearchResult) -> some View {
        if result.tasks.isEmpty {
            emptyState(
                title: liveEmptyStateTitle(for: result),
                message: liveEmptyStateMessage(for: result)
            )
            .orbitPhoneListRow(insets: phoneListInsets(bottom: Layout.phoneRowSpacing))
        } else {
            let liveTasks = Array(result.tasks.enumerated())

            ForEach(liveTasks, id: \.element.id) { entry in
                liveTaskRow(entry.element)
                    .orbitPhoneListRow(
                        insets: phoneListInsets(
                            bottom: entry.offset == liveTasks.indices.last
                                ? Layout.phoneRowSpacing
                                : Layout.phoneRowSpacing
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private var archivedSectionContent: some View {
        if archivedSessionCount == 0 {
            emptyState(
                title: "No Archived Sessions Yet",
                message: "End a session to build your searchable history timeline."
            )
            .orbitPhoneListRow(insets: phoneListInsets(bottom: Layout.phoneContentInsets.bottom))
        } else if trimmedQuery.isEmpty {
            emptyState(
                title: "Start Typing To Search History",
                message: "Live tasks stay visible above. Archived sessions appear here after you start typing."
            )
            .orbitPhoneListRow(insets: phoneListInsets(bottom: Layout.phoneContentInsets.bottom))
        } else if archivedSearchResults.isEmpty {
            emptyState(
                title: "No Archived Matches Found",
                message: "Try a different phrase or switch between Completed, Created, Open, and All."
            )
            .orbitPhoneListRow(insets: phoneListInsets(bottom: Layout.phoneContentInsets.bottom))
        } else {
            let dayGroups = Array(archivedSearchResults.enumerated())

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
                                    bottom: isLastArchivedSearchRow(
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

    private var headerMessage: String {
        if store.activeSession != nil {
            return "Live tasks appear first. Archived results show below after you start typing."
        }
        return "Search archived session names and task text from the toolbar search field."
    }

    private var liveSearchResult: LiveTaskSearchResult? {
        SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: store.activeSession,
            taskDrafts: Array(store.taskDrafts),
            query: model.query,
            filter: model.filter
        )
    }

    private var archivedSessionCount: Int {
        model.sessions.filter { session in
            session.endedAt != nil && session.id != model.excludingActiveSessionID
        }.count
    }

    private var trimmedQuery: String {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var archivedSearchResults: [HistorySearchDayGroup] {
        SessionHistorySearchSupport.dayGroups(
            from: model.sessions,
            excludingActiveSessionID: model.excludingActiveSessionID,
            query: model.query,
            filter: model.filter
        )
    }

    private var archivedSectionIntro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Archived History")
                .orbitFont(.headline, weight: .semibold)
                .foregroundStyle(OrbitTheme.Palette.orbitLine)

            Text(archivedIntroMessage)
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var archivedIntroMessage: String {
        if archivedSessionCount == 0 {
            return "Ended sessions will show up here once you have saved history."
        }
        if trimmedQuery.isEmpty {
            return "Type in the search field to search ended sessions by name and task text."
        }

        let matchedSessionCount = archivedSearchResults.reduce(into: 0) { count, dayGroup in
            count += dayGroup.sessions.count
        }
        return "\(matchedSessionCount) matching session\(matchedSessionCount == 1 ? "" : "s"), grouped by day."
    }

    private func liveSectionHeader(_ result: LiveTaskSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Live Tasks")
                .orbitFont(.headline, weight: .semibold)
                .foregroundStyle(OrbitTheme.Palette.orbitLine)

            Text(liveSectionMetadata(for: result))
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Layout.phoneContentInsets.leading)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private func liveSectionMetadata(for result: LiveTaskSearchResult) -> String {
        let startedAt = result.session.startedAt.formatted(date: .omitted, time: .shortened)
        let shownCount = result.tasks.count
        let shownLabel = "\(shownCount) \(shownCount == 1 ? "task" : "tasks") shown"

        if !trimmedQuery.isEmpty, result.isSessionNameMatch {
            return "\(result.session.name) • Started \(startedAt) • Session name matched • \(shownLabel)"
        }

        return "\(result.session.name) • Started \(startedAt) • \(shownLabel)"
    }

    private func liveEmptyStateTitle(for result: LiveTaskSearchResult) -> String {
        if trimmedQuery.isEmpty || result.isSessionNameMatch {
            return "No Live Tasks In This Filter"
        }
        return "No Live Tasks Match This Search"
    }

    private func liveEmptyStateMessage(for result: LiveTaskSearchResult) -> String {
        if trimmedQuery.isEmpty || result.isSessionNameMatch {
            return "Try a different task filter or capture a new task in the current session."
        }
        return "Try a different phrase or switch between Completed, Created, Open, and All."
    }

    private func liveTaskRow(_ draft: AppFeature.State.TaskDraft) -> some View {
        SessionTaskInteractiveRow(
            draft: draft,
            onEditRequested: {
                store.send(.sessionTaskEditTapped(draft.id))
            },
            onPrioritySet: { priority in
                store.send(.sessionTaskPrioritySetTapped(draft.id, priority))
            },
            onToggleCompletion: {
                store.send(.sessionTaskCompletionToggled(draft.id, !draft.isCompleted))
            },
            onToggleChecklistLine: { lineIndex in
                store.send(.sessionTaskChecklistLineToggled(draft.id, lineIndex))
            },
            onDeleteRequested: {
                store.send(.sessionTaskDeleteTapped(draft.id))
            }
        )
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

    private func sessionGroupSummary(_ sessionGroup: HistorySearchSessionGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sessionGroup.session.name)
                .orbitFont(.subheadline, weight: .semibold)

            Text(sessionMetadata(for: sessionGroup))
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
        }
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

    private func dayCountLabel(for dayGroup: HistorySearchDayGroup) -> String {
        let taskLabel = "\(dayGroup.totalTaskCount) \(dayGroup.totalTaskCount == 1 ? "task" : "tasks")"
        let sessionLabel = "\(dayGroup.sessions.count) \(dayGroup.sessions.count == 1 ? "session" : "sessions")"
        return "\(taskLabel) • \(sessionLabel)"
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

    private func isLastArchivedSearchRow(
        dayIndex: Int,
        sessionIndex: Int,
        in dayGroups: [(offset: Int, element: HistorySearchDayGroup)]
    ) -> Bool {
        guard let lastDayIndex = dayGroups.indices.last else { return false }
        guard let lastSessionIndex = dayGroups[lastDayIndex].element.sessions.indices.last else { return false }
        return dayIndex == lastDayIndex && sessionIndex == lastSessionIndex
    }

    private func phoneListInsets(
        top: CGFloat = 0,
        bottom: CGFloat = Layout.phoneRowSpacing
    ) -> EdgeInsets {
        EdgeInsets(
            top: top,
            leading: Layout.phoneContentInsets.leading,
            bottom: bottom,
            trailing: Layout.phoneContentInsets.trailing
        )
    }
}
#endif
