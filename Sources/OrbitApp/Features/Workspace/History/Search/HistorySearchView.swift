import SwiftUI

struct HistorySearchView: View {
    @ObservedObject var model: HistorySearchPanelModel

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .orbitOnExitCommand {
            model.closeRequested()
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(searchResults) { dayGroup in
                        dayGroupView(dayGroup)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
        }
    }

    private var archivedSessionCount: Int {
        model.sessions.filter { session in
            session.endedAt != nil && session.id != model.excludingActiveSessionID
        }.count
    }

    private var trimmedQuery: String {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [HistorySearchDayGroup] {
        SessionHistorySearchSupport.dayGroups(
            from: model.sessions,
            excludingActiveSessionID: model.excludingActiveSessionID,
            query: model.query,
            filter: model.filter
        )
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
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                .stroke(OrbitTheme.Palette.glassBorderStrong, lineWidth: 1)
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
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
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
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
        )
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
}
