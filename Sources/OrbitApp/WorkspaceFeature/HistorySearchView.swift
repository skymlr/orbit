import SwiftUI

struct HistorySearchView: View {
    @ObservedObject var model: HistorySearchPanelModel

    private let searchFilterOrder: [HistoryTaskFilter] = [.all, .completed, .open]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("Task filter", selection: $model.filter) {
                ForEach(searchFilterOrder) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onExitCommand {
            model.closeRequested()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search History")
                .font(.title3.weight(.bold))

            Text("Find archived tasks by session name or task text using the toolbar search field.")
                .font(.caption)
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
                message: "Try a different phrase or switch between All, Completed, and Open."
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SessionHistoryBrowserSupport.dayLabel(dayGroup.day))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(OrbitTheme.Palette.orbitLine)

                    Text(dayCountLabel(for: dayGroup))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Go to Day") {
                    model.goToDay(dayGroup.day)
                }
                .buttonStyle(.orbitSecondary)
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionGroup.session.name)
                        .font(.subheadline.weight(.semibold))

                    Text(sessionMetadata(for: sessionGroup))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Go to Session") {
                    model.goToSession(sessionGroup.session)
                }
                .buttonStyle(.orbitSecondary)
            }

            if sessionGroup.tasks.isEmpty {
                Text("No tasks in the current filter for this matching session.")
                    .font(.caption)
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
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.caption)
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
