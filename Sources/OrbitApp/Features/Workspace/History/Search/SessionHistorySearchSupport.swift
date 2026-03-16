import Foundation

struct HistorySearchDayGroup: Equatable, Identifiable {
    let day: Date
    let sessions: [HistorySearchSessionGroup]

    var id: Date { day }

    var totalTaskCount: Int {
        sessions.reduce(into: 0) { count, session in
            count += session.tasks.count
        }
    }
}

struct HistorySearchSessionGroup: Equatable, Identifiable {
    let session: FocusSessionRecord
    let tasks: [FocusTaskRecord]
    let isSessionNameMatch: Bool

    var id: UUID { session.id }
}

enum SessionHistorySearchSupport {
    static func dayGroups(
        from sessions: [FocusSessionRecord],
        excludingActiveSessionID: UUID?,
        query: String,
        filter: HistoryTaskFilter,
        calendar: Calendar = .current
    ) -> [HistorySearchDayGroup] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        let historicalSessions = sessions
            .filter { session in
                session.endedAt != nil && session.id != excludingActiveSessionID
            }

        let matchingGroups = historicalSessions.compactMap { session -> HistorySearchSessionGroup? in
            let isSessionNameMatch = session.name.localizedCaseInsensitiveContains(normalizedQuery)
            let filteredTasks = SessionHistoryBrowserSupport.filteredTasks(for: session, filter: filter)
            let matchingFilteredTasks = filteredTasks.filter { task in
                task.markdown.localizedCaseInsensitiveContains(normalizedQuery)
            }

            if isSessionNameMatch {
                return HistorySearchSessionGroup(
                    session: session,
                    tasks: filteredTasks,
                    isSessionNameMatch: true
                )
            }

            guard !matchingFilteredTasks.isEmpty else { return nil }
            return HistorySearchSessionGroup(
                session: session,
                tasks: matchingFilteredTasks,
                isSessionNameMatch: false
            )
        }

        let groupedByDay = Dictionary(grouping: matchingGroups) { group in
            calendar.startOfDay(for: group.session.startedAt)
        }

        return groupedByDay.keys
            .sorted(by: >)
            .map { day in
                HistorySearchDayGroup(
                    day: day,
                    sessions: groupedByDay[day, default: []]
                        .sorted(by: { $0.session.startedAt > $1.session.startedAt })
                )
            }
    }
}
