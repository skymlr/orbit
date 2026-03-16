import Foundation

enum HistoryTaskFilter: String, CaseIterable, Identifiable {
    case completed
    case all
    case open
    case createdInSession

    var id: Self { self }

    static let sessionHistoryTabs: [Self] = [.completed, .createdInSession, .open, .all]
    static let searchTabs: [Self] = [.completed, .createdInSession, .open, .all]

    var title: String {
        switch self {
        case .completed:
            return "Completed"
        case .all:
            return "All"
        case .open:
            return "Open"
        case .createdInSession:
            return "Created"
        }
    }
}

struct HistoryDayGroup: Equatable, Identifiable {
    let day: Date
    let sessions: [FocusSessionRecord]

    var id: Date { day }
}

enum HistoryDayNavigationDirection {
    case previous
    case next
}

enum SessionHistoryBrowserSupport {
    static func dayGroups(
        from sessions: [FocusSessionRecord],
        excludingActiveSessionID: UUID?,
        calendar: Calendar = .current
    ) -> [HistoryDayGroup] {
        let historicalSessions = sessions
            .filter { session in
                session.endedAt != nil && session.id != excludingActiveSessionID
            }

        let groupedByDay = Dictionary(grouping: historicalSessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        return groupedByDay.keys
            .sorted(by: >)
            .map { day in
                HistoryDayGroup(
                    day: day,
                    sessions: groupedByDay[day, default: []]
                        .sorted(by: { $0.startedAt > $1.startedAt })
                )
            }
    }

    static func normalizedDay(
        for date: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.startOfDay(for: date)
    }

    static func defaultSelectedDay(
        from groups: [HistoryDayGroup],
        fallback: Date,
        calendar: Calendar = .current
    ) -> Date {
        groups.first?.day ?? normalizedDay(for: fallback, calendar: calendar)
    }

    static func sessions(
        on day: Date,
        from groups: [HistoryDayGroup],
        calendar: Calendar = .current
    ) -> [FocusSessionRecord] {
        let normalized = normalizedDay(for: day, calendar: calendar)
        return groups.first(where: { calendar.isDate($0.day, inSameDayAs: normalized) })?.sessions ?? []
    }

    static func defaultSessionID(
        on day: Date,
        groups: [HistoryDayGroup],
        calendar: Calendar = .current
    ) -> UUID? {
        sessions(on: day, from: groups, calendar: calendar).first?.id
    }

    static func resolveSelectedSession(
        id: UUID?,
        on day: Date,
        groups: [HistoryDayGroup],
        calendar: Calendar = .current
    ) -> FocusSessionRecord? {
        let daySessions = sessions(on: day, from: groups, calendar: calendar)
        guard !daySessions.isEmpty else { return nil }

        if let id,
           let selected = daySessions.first(where: { $0.id == id }) {
            return selected
        }

        return daySessions.first
    }

    static func filteredTasks(
        for session: FocusSessionRecord,
        filter: HistoryTaskFilter
    ) -> [FocusTaskRecord] {
        let sortedTasks = session.tasks.sorted(by: { $0.createdAt > $1.createdAt })

        switch filter {
        case .completed:
            return sortedTasks.filter { $0.completedAt != nil }
        case .all:
            return sortedTasks
        case .open:
            return sortedTasks.filter { $0.completedAt == nil }
        case .createdInSession:
            return sortedTasks.filter(\.wasCreatedInSession)
        }
    }

    static func adjacentDay(
        from day: Date,
        groups: [HistoryDayGroup],
        direction: HistoryDayNavigationDirection,
        calendar: Calendar = .current
    ) -> Date? {
        let normalized = normalizedDay(for: day, calendar: calendar)

        if let currentIndex = groups.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: normalized) }) {
            switch direction {
            case .previous:
                let previousIndex = currentIndex + 1
                guard groups.indices.contains(previousIndex) else { return nil }
                return groups[previousIndex].day
            case .next:
                let nextIndex = currentIndex - 1
                guard groups.indices.contains(nextIndex) else { return nil }
                return groups[nextIndex].day
            }
        }

        switch direction {
        case .previous:
            return groups
                .map(\.day)
                .filter { $0 < normalized }
                .max()
        case .next:
            return groups
                .map(\.day)
                .filter { $0 > normalized }
                .min()
        }
    }

    static func dayLabel(_ day: Date, calendar: Calendar = .current) -> String {
        let formatted = day.formatted(date: .abbreviated, time: .omitted)
        if calendar.isDateInToday(day) {
            return "Today • \(formatted)"
        }
        if calendar.isDateInYesterday(day) {
            return "Yesterday • \(formatted)"
        }
        return formatted
    }
}
