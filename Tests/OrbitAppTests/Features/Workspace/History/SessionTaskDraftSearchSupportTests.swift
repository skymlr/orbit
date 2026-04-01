import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct SessionTaskDraftSearchSupportTests {
    @Test
    func missingActiveSessionReturnsNoLiveSearchResult() {
        let result = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: nil,
            taskDrafts: [makeTaskDraft(markdown: "Ship search", createdAt: Date(timeIntervalSince1970: 0))],
            query: "ship",
            filter: .all
        )

        #expect(result == nil)
    }

    @Test
    func emptyQueryReturnsAllLiveTasksSortedUsingLiveRules() {
        let calendar = liveSearchTestCalendar
        let activeSession = makeLiveSearchSession(
            name: "Sprint",
            startedAt: liveSearchDate(2026, 3, 5, 9, 0, calendar: calendar)
        )

        let completedTask = makeTaskDraft(
            markdown: "Completed task",
            priority: .high,
            createdAt: liveSearchDate(2026, 3, 5, 9, 40, calendar: calendar),
            completedAt: liveSearchDate(2026, 3, 5, 9, 50, calendar: calendar)
        )
        let lowPriorityOpenTask = makeTaskDraft(
            markdown: "Open low",
            priority: .low,
            createdAt: liveSearchDate(2026, 3, 5, 9, 45, calendar: calendar)
        )
        let highPriorityOpenTask = makeTaskDraft(
            markdown: "Open high",
            priority: .high,
            createdAt: liveSearchDate(2026, 3, 5, 9, 30, calendar: calendar)
        )

        let result = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: activeSession,
            taskDrafts: [completedTask, lowPriorityOpenTask, highPriorityOpenTask],
            query: "",
            filter: .all
        )

        #expect(result?.tasks.map(\.id) == [highPriorityOpenTask.id, lowPriorityOpenTask.id, completedTask.id])
        #expect(result?.isSessionNameMatch == false)
    }

    @Test
    func taskTextMatchReturnsOnlyMatchingLiveTasks() {
        let calendar = liveSearchTestCalendar
        let activeSession = makeLiveSearchSession(
            name: "Sprint",
            startedAt: liveSearchDate(2026, 3, 5, 9, 0, calendar: calendar)
        )

        let matchingTask = makeTaskDraft(
            markdown: "Ship search panel",
            createdAt: liveSearchDate(2026, 3, 5, 9, 10, calendar: calendar)
        )
        let otherTask = makeTaskDraft(
            markdown: "Review spacing",
            createdAt: liveSearchDate(2026, 3, 5, 9, 20, calendar: calendar)
        )

        let result = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: activeSession,
            taskDrafts: [otherTask, matchingTask],
            query: "search panel",
            filter: .all
        )

        #expect(result?.tasks.map(\.id) == [matchingTask.id])
        #expect(result?.isSessionNameMatch == false)
    }

    @Test
    func sessionNameMatchReturnsAllTasksThatPassCurrentFilter() {
        let calendar = liveSearchTestCalendar
        let activeSession = makeLiveSearchSession(
            name: "Deep Work Sprint",
            startedAt: liveSearchDate(2026, 3, 5, 9, 0, calendar: calendar)
        )

        let completedTask = makeTaskDraft(
            markdown: "Review notes",
            createdAt: liveSearchDate(2026, 3, 5, 9, 10, calendar: calendar),
            completedAt: liveSearchDate(2026, 3, 5, 9, 20, calendar: calendar)
        )
        let openTask = makeTaskDraft(
            markdown: "Queue follow-up",
            createdAt: liveSearchDate(2026, 3, 5, 9, 30, calendar: calendar)
        )

        let result = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: activeSession,
            taskDrafts: [completedTask, openTask],
            query: "deep work",
            filter: .open
        )

        #expect(result?.isSessionNameMatch == true)
        #expect(result?.tasks.map(\.id) == [openTask.id])
    }

    @Test
    func historyStyleFiltersApplyToLiveTasks() {
        let calendar = liveSearchTestCalendar
        let activeSession = makeLiveSearchSession(
            name: "Sprint",
            startedAt: liveSearchDate(2026, 3, 5, 9, 0, calendar: calendar)
        )

        let completedTask = makeTaskDraft(
            markdown: "Completed",
            priority: .medium,
            createdAt: liveSearchDate(2026, 3, 5, 9, 30, calendar: calendar),
            completedAt: liveSearchDate(2026, 3, 5, 9, 45, calendar: calendar)
        )
        let carriedTask = makeTaskDraft(
            markdown: "Carried",
            priority: .low,
            createdAt: liveSearchDate(2026, 3, 5, 9, 20, calendar: calendar),
            carriedFromTaskID: UUID()
        )
        let createdTask = makeTaskDraft(
            markdown: "Created here",
            priority: .high,
            createdAt: liveSearchDate(2026, 3, 5, 9, 40, calendar: calendar)
        )

        let all = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: activeSession,
            taskDrafts: [completedTask, carriedTask, createdTask],
            query: "",
            filter: .all
        )
        let completed = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: activeSession,
            taskDrafts: [completedTask, carriedTask, createdTask],
            query: "",
            filter: .completed
        )
        let open = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: activeSession,
            taskDrafts: [completedTask, carriedTask, createdTask],
            query: "",
            filter: .open
        )
        let created = SessionTaskDraftSearchSupport.liveSearchResult(
            activeSession: activeSession,
            taskDrafts: [completedTask, carriedTask, createdTask],
            query: "",
            filter: .createdInSession
        )

        #expect(all?.tasks.map(\.id) == [createdTask.id, carriedTask.id, completedTask.id])
        #expect(completed?.tasks.map(\.id) == [completedTask.id])
        #expect(open?.tasks.map(\.id) == [createdTask.id, carriedTask.id])
        #expect(created?.tasks.map(\.id) == [createdTask.id, completedTask.id])
    }
}

private let liveSearchTestCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func liveSearchDate(
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

private func makeLiveSearchSession(
    id: UUID = UUID(),
    name: String,
    startedAt: Date
) -> FocusSessionRecord {
    FocusSessionRecord(
        id: id,
        name: name,
        startedAt: startedAt,
        endedAt: nil,
        endedReason: nil,
        tasks: []
    )
}

private func makeTaskDraft(
    id: UUID = UUID(),
    markdown: String,
    priority: NotePriority = .none,
    createdAt: Date,
    completedAt: Date? = nil,
    carriedFromTaskID: UUID? = nil
) -> AppFeature.State.TaskDraft {
    AppFeature.State.TaskDraft(
        id: id,
        categories: [],
        markdown: markdown,
        priority: priority,
        completedAt: completedAt,
        carriedFromTaskID: carriedFromTaskID,
        carriedFromSessionName: carriedFromTaskID == nil ? nil : "Earlier Session",
        createdAt: createdAt
    )
}
