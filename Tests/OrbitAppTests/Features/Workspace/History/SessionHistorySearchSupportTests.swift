import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct SessionHistorySearchSupportTests {
    @Test
    func caseInsensitiveSessionNameMatches() {
        let calendar = testCalendar

        let matchingSession = makeSession(
            name: "Deep Work Sprint",
            startedAt: date(2026, 3, 5, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            tasks: [
                makeTask(
                    sessionID: UUID(),
                    markdown: "Review notes",
                    createdAt: date(2026, 3, 5, 9, 10, calendar: calendar),
                    completedAt: nil
                )
            ]
        )

        let groups = SessionHistorySearchSupport.dayGroups(
            from: [matchingSession],
            excludingActiveSessionID: nil,
            query: "deep work",
            filter: .all,
            calendar: calendar
        )

        #expect(groups.count == 1)
        #expect(groups[0].sessions.count == 1)
        #expect(groups[0].sessions[0].session.id == matchingSession.id)
        #expect(groups[0].sessions[0].isSessionNameMatch)
    }

    @Test
    func caseInsensitiveTaskMarkdownMatches() {
        let calendar = testCalendar

        let matchingTask = makeTask(
            markdown: "Draft RELEASE notes",
            createdAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            completedAt: nil
        )

        let session = makeSession(
            startedAt: date(2026, 3, 5, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 11, 0, calendar: calendar),
            tasks: [matchingTask]
        )

        let groups = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "release",
            filter: .all,
            calendar: calendar
        )

        #expect(groups.count == 1)
        #expect(groups[0].sessions.count == 1)
        #expect(groups[0].sessions[0].tasks.map(\.id) == [matchingTask.id])
        #expect(!groups[0].sessions[0].isSessionNameMatch)
    }

    @Test
    func emptyQueryReturnsNoArchivedGroups() {
        let calendar = testCalendar

        let session = makeSession(
            startedAt: date(2026, 3, 5, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            tasks: [makeTask(markdown: "Review notes", createdAt: date(2026, 3, 5, 9, 10, calendar: calendar), completedAt: nil)]
        )

        let groups = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "   ",
            filter: .all,
            calendar: calendar
        )

        #expect(groups.isEmpty)
    }

    @Test
    func groupsResultsByDayAndSessionDescending() {
        let calendar = testCalendar

        let newestSession = makeSession(
            name: "Planning",
            startedAt: date(2026, 3, 6, 11, 0, calendar: calendar),
            endedAt: date(2026, 3, 6, 12, 0, calendar: calendar),
            tasks: [makeTask(markdown: "roadmap", createdAt: date(2026, 3, 6, 11, 10, calendar: calendar), completedAt: nil)]
        )

        let olderSameDay = makeSession(
            name: "Review",
            startedAt: date(2026, 3, 6, 8, 0, calendar: calendar),
            endedAt: date(2026, 3, 6, 9, 0, calendar: calendar),
            tasks: [makeTask(markdown: "roadmap review", createdAt: date(2026, 3, 6, 8, 10, calendar: calendar), completedAt: nil)]
        )

        let previousDay = makeSession(
            name: "Sync",
            startedAt: date(2026, 3, 5, 14, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 15, 0, calendar: calendar),
            tasks: [makeTask(markdown: "roadmap sync", createdAt: date(2026, 3, 5, 14, 10, calendar: calendar), completedAt: nil)]
        )

        let groups = SessionHistorySearchSupport.dayGroups(
            from: [olderSameDay, previousDay, newestSession],
            excludingActiveSessionID: nil,
            query: "roadmap",
            filter: .all,
            calendar: calendar
        )

        #expect(groups.count == 2)
        #expect(calendar.isDate(groups[0].day, inSameDayAs: date(2026, 3, 6, 0, 0, calendar: calendar)))
        #expect(calendar.isDate(groups[1].day, inSameDayAs: date(2026, 3, 5, 0, 0, calendar: calendar)))
        #expect(groups[0].sessions.map(\.session.id) == [newestSession.id, olderSameDay.id])
        #expect(groups[1].sessions.map(\.session.id) == [previousDay.id])
    }

    @Test
    func sessionNameOnlyMatchIncludesSessionGroup() {
        let calendar = testCalendar

        let firstTask = makeTask(
            markdown: "Inbox zero",
            createdAt: date(2026, 3, 5, 12, 0, calendar: calendar),
            completedAt: nil
        )
        let secondTask = makeTask(
            markdown: "Send status",
            createdAt: date(2026, 3, 5, 11, 0, calendar: calendar),
            completedAt: date(2026, 3, 5, 11, 20, calendar: calendar)
        )

        let session = makeSession(
            name: "Planning Orbit",
            startedAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 13, 0, calendar: calendar),
            tasks: [secondTask, firstTask]
        )

        let groups = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "orbit",
            filter: .all,
            calendar: calendar
        )

        #expect(groups.count == 1)
        #expect(groups[0].sessions.count == 1)
        #expect(groups[0].sessions[0].isSessionNameMatch)
        #expect(groups[0].sessions[0].tasks.map(\.id) == [firstTask.id, secondTask.id])
    }

    @Test
    func taskTextOnlyMatchIncludesOnlyMatchingTasks() {
        let calendar = testCalendar

        let matchingTask = makeTask(
            markdown: "Ship search panel",
            createdAt: date(2026, 3, 5, 12, 0, calendar: calendar),
            completedAt: nil
        )
        let nonMatchingTask = makeTask(
            markdown: "Review spacing",
            createdAt: date(2026, 3, 5, 11, 0, calendar: calendar),
            completedAt: nil
        )

        let session = makeSession(
            name: "Implementation",
            startedAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 13, 0, calendar: calendar),
            tasks: [nonMatchingTask, matchingTask]
        )

        let groups = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "search panel",
            filter: .all,
            calendar: calendar
        )

        #expect(groups.count == 1)
        #expect(groups[0].sessions.count == 1)
        #expect(groups[0].sessions[0].tasks.map(\.id) == [matchingTask.id])
        #expect(!groups[0].sessions[0].isSessionNameMatch)
    }

    @Test
    func filterBehaviorAppliesInsideGroupedResults() {
        let calendar = testCalendar

        let completedTask = makeTask(
            markdown: "History cleanup",
            createdAt: date(2026, 3, 5, 12, 0, calendar: calendar),
            completedAt: date(2026, 3, 5, 12, 20, calendar: calendar)
        )
        let openTask = makeTask(
            markdown: "History polish",
            createdAt: date(2026, 3, 5, 11, 0, calendar: calendar),
            completedAt: nil
        )

        let carriedTask = makeTask(
            markdown: "History carryover",
            createdAt: date(2026, 3, 5, 10, 30, calendar: calendar),
            completedAt: nil,
            carriedFromTaskID: UUID()
        )

        let session = makeSession(
            name: "History Search",
            startedAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 13, 0, calendar: calendar),
            tasks: [openTask, completedTask, carriedTask]
        )

        let all = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "history",
            filter: .all,
            calendar: calendar
        )
        let completed = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "history",
            filter: .completed,
            calendar: calendar
        )
        let open = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "history",
            filter: .open,
            calendar: calendar
        )
        let createdHere = SessionHistorySearchSupport.dayGroups(
            from: [session],
            excludingActiveSessionID: nil,
            query: "history",
            filter: .createdInSession,
            calendar: calendar
        )

        #expect(all[0].sessions[0].tasks.map(\.id) == [completedTask.id, openTask.id, carriedTask.id])
        #expect(completed[0].sessions[0].tasks.map(\.id) == [completedTask.id])
        #expect(open[0].sessions[0].tasks.map(\.id) == [openTask.id, carriedTask.id])
        #expect(createdHere[0].sessions[0].tasks.map(\.id) == [completedTask.id, openTask.id])
    }

    @Test
    func excludesActiveSessionFromSearchResults() {
        let calendar = testCalendar

        let activeSession = makeSession(
            startedAt: date(2026, 3, 5, 13, 0, calendar: calendar),
            endedAt: nil,
            tasks: [makeTask(markdown: "search me", createdAt: date(2026, 3, 5, 13, 10, calendar: calendar), completedAt: nil)]
        )
        let archivedSession = makeSession(
            startedAt: date(2026, 3, 5, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            tasks: [makeTask(markdown: "search me too", createdAt: date(2026, 3, 5, 9, 10, calendar: calendar), completedAt: nil)]
        )

        let groups = SessionHistorySearchSupport.dayGroups(
            from: [activeSession, archivedSession],
            excludingActiveSessionID: activeSession.id,
            query: "search me",
            filter: .all,
            calendar: calendar
        )

        #expect(groups.count == 1)
        #expect(groups[0].sessions.map(\.session.id) == [archivedSession.id])
    }
}

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int,
    calendar: Calendar
) -> Date {
    calendar.date(
        from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}

private func makeSession(
    id: UUID = UUID(),
    name: String = "Session",
    startedAt: Date,
    endedAt: Date?,
    tasks: [FocusTaskRecord]
) -> FocusSessionRecord {
    FocusSessionRecord(
        id: id,
        name: name,
        startedAt: startedAt,
        endedAt: endedAt,
        endedReason: endedAt == nil ? nil : .manual,
        tasks: tasks.map { task in
            var task = task
            task.sessionID = id
            return task
        }
    )
}

private func makeTask(
    id: UUID = UUID(),
    sessionID: UUID = UUID(),
    markdown: String,
    createdAt: Date,
    completedAt: Date?,
    carriedFromTaskID: UUID? = nil
) -> FocusTaskRecord {
    FocusTaskRecord(
        id: id,
        sessionID: sessionID,
        categories: [],
        markdown: markdown,
        priority: .none,
        completedAt: completedAt,
        carriedFromTaskID: carriedFromTaskID,
        carriedFromSessionName: nil,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}
