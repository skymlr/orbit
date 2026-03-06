import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct SessionHistoryBrowserSupportTests {
    @Test
    func dayGroupsExcludeActiveAndSort() {
        let calendar = testCalendar

        let dayFiveStart = date(2026, 3, 5, 0, 0, calendar: calendar)
        let dayFourStart = date(2026, 3, 4, 0, 0, calendar: calendar)
        let dayTwoStart = date(2026, 3, 2, 0, 0, calendar: calendar)

        let active = makeSession(
            startedAt: date(2026, 3, 5, 11, 0, calendar: calendar),
            endedAt: nil,
            tasks: []
        )

        let morning = makeSession(
            startedAt: date(2026, 3, 5, 9, 30, calendar: calendar),
            endedAt: date(2026, 3, 5, 10, 10, calendar: calendar),
            tasks: []
        )

        let dawn = makeSession(
            startedAt: date(2026, 3, 5, 6, 15, calendar: calendar),
            endedAt: date(2026, 3, 5, 7, 0, calendar: calendar),
            tasks: []
        )

        let evening = makeSession(
            startedAt: date(2026, 3, 4, 18, 0, calendar: calendar),
            endedAt: date(2026, 3, 4, 19, 0, calendar: calendar),
            tasks: []
        )

        let older = makeSession(
            startedAt: date(2026, 3, 2, 14, 0, calendar: calendar),
            endedAt: date(2026, 3, 2, 15, 0, calendar: calendar),
            tasks: []
        )

        let groups = SessionHistoryBrowserSupport.dayGroups(
            from: [active, morning, dawn, evening, older],
            excludingActiveSessionID: active.id,
            calendar: calendar
        )

        #expect(groups.count == 3)
        #expect(calendar.isDate(groups[0].day, inSameDayAs: dayFiveStart))
        #expect(calendar.isDate(groups[1].day, inSameDayAs: dayFourStart))
        #expect(calendar.isDate(groups[2].day, inSameDayAs: dayTwoStart))

        #expect(groups[0].sessions.map(\.id) == [morning.id, dawn.id])
        #expect(groups[1].sessions.map(\.id) == [evening.id])
        #expect(groups[2].sessions.map(\.id) == [older.id])
    }

    @Test
    func defaultAndResolvedSessionSelectionUsesMostRecentOnDay() {
        let calendar = testCalendar

        let primaryDay = date(2026, 3, 5, 0, 0, calendar: calendar)

        let latest = makeSession(
            startedAt: date(2026, 3, 5, 16, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 17, 0, calendar: calendar),
            tasks: []
        )
        let earlier = makeSession(
            startedAt: date(2026, 3, 5, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            tasks: []
        )

        let groups = SessionHistoryBrowserSupport.dayGroups(
            from: [earlier, latest],
            excludingActiveSessionID: nil,
            calendar: calendar
        )

        let defaultID = SessionHistoryBrowserSupport.defaultSessionID(
            on: primaryDay,
            groups: groups,
            calendar: calendar
        )

        let resolvedNil = SessionHistoryBrowserSupport.resolveSelectedSession(
            id: nil,
            on: primaryDay,
            groups: groups,
            calendar: calendar
        )

        let unresolvedID = UUID(uuidString: "A315F3DF-7D4C-4E6D-AF3F-CB55FD95E5DB")!
        let resolvedMissing = SessionHistoryBrowserSupport.resolveSelectedSession(
            id: unresolvedID,
            on: primaryDay,
            groups: groups,
            calendar: calendar
        )

        #expect(defaultID == latest.id)
        #expect(resolvedNil?.id == latest.id)
        #expect(resolvedMissing?.id == latest.id)
    }

    @Test
    func filteredTasksRespectsCompletedAllAndOpenModes() {
        let calendar = testCalendar

        let completedNewest = makeTask(
            markdown: "Done newest",
            createdAt: date(2026, 3, 5, 12, 0, calendar: calendar),
            completedAt: date(2026, 3, 5, 12, 30, calendar: calendar)
        )

        let openTask = makeTask(
            markdown: "Open",
            createdAt: date(2026, 3, 5, 11, 0, calendar: calendar),
            completedAt: nil
        )

        let completedOldest = makeTask(
            markdown: "Done oldest",
            createdAt: date(2026, 3, 5, 10, 0, calendar: calendar),
            completedAt: date(2026, 3, 5, 10, 45, calendar: calendar)
        )

        let session = makeSession(
            startedAt: date(2026, 3, 5, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 5, 13, 0, calendar: calendar),
            tasks: [completedOldest, completedNewest, openTask]
        )

        let completed = SessionHistoryBrowserSupport.filteredTasks(for: session, filter: .completed)
        let all = SessionHistoryBrowserSupport.filteredTasks(for: session, filter: .all)
        let open = SessionHistoryBrowserSupport.filteredTasks(for: session, filter: .open)

        #expect(completed.map(\.id) == [completedNewest.id, completedOldest.id])
        #expect(all.map(\.id) == [completedNewest.id, openTask.id, completedOldest.id])
        #expect(open.map(\.id) == [openTask.id])
    }

    @Test
    func adjacentDayNavigationHandlesBoundariesAndGaps() {
        let calendar = testCalendar

        let newest = makeSession(
            startedAt: date(2026, 3, 6, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 6, 10, 0, calendar: calendar),
            tasks: []
        )

        let middle = makeSession(
            startedAt: date(2026, 3, 4, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 4, 10, 0, calendar: calendar),
            tasks: []
        )

        let oldest = makeSession(
            startedAt: date(2026, 3, 1, 9, 0, calendar: calendar),
            endedAt: date(2026, 3, 1, 10, 0, calendar: calendar),
            tasks: []
        )

        let groups = SessionHistoryBrowserSupport.dayGroups(
            from: [oldest, newest, middle],
            excludingActiveSessionID: nil,
            calendar: calendar
        )

        let middleDay = date(2026, 3, 4, 0, 0, calendar: calendar)
        let gapDay = date(2026, 3, 5, 0, 0, calendar: calendar)
        let newestDay = date(2026, 3, 6, 0, 0, calendar: calendar)
        let oldestDay = date(2026, 3, 1, 0, 0, calendar: calendar)

        let middlePrevious = SessionHistoryBrowserSupport.adjacentDay(
            from: middleDay,
            groups: groups,
            direction: .previous,
            calendar: calendar
        )
        let middleNext = SessionHistoryBrowserSupport.adjacentDay(
            from: middleDay,
            groups: groups,
            direction: .next,
            calendar: calendar
        )

        let gapPrevious = SessionHistoryBrowserSupport.adjacentDay(
            from: gapDay,
            groups: groups,
            direction: .previous,
            calendar: calendar
        )
        let gapNext = SessionHistoryBrowserSupport.adjacentDay(
            from: gapDay,
            groups: groups,
            direction: .next,
            calendar: calendar
        )

        let newestNext = SessionHistoryBrowserSupport.adjacentDay(
            from: newestDay,
            groups: groups,
            direction: .next,
            calendar: calendar
        )
        let oldestPrevious = SessionHistoryBrowserSupport.adjacentDay(
            from: oldestDay,
            groups: groups,
            direction: .previous,
            calendar: calendar
        )

        #expect(calendar.isDate(middlePrevious!, inSameDayAs: oldestDay))
        #expect(calendar.isDate(middleNext!, inSameDayAs: newestDay))

        #expect(calendar.isDate(gapPrevious!, inSameDayAs: middleDay))
        #expect(calendar.isDate(gapNext!, inSameDayAs: newestDay))

        #expect(newestNext == nil)
        #expect(oldestPrevious == nil)
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
    startedAt: Date,
    endedAt: Date?,
    tasks: [FocusTaskRecord]
) -> FocusSessionRecord {
    FocusSessionRecord(
        id: id,
        name: "Session",
        startedAt: startedAt,
        endedAt: endedAt,
        endedReason: endedAt == nil ? nil : .manual,
        tasks: tasks
    )
}

private func makeTask(
    id: UUID = UUID(),
    markdown: String,
    createdAt: Date,
    completedAt: Date?
) -> FocusTaskRecord {
    FocusTaskRecord(
        id: id,
        sessionID: UUID(),
        categories: [],
        markdown: markdown,
        priority: .none,
        completedAt: completedAt,
        carriedFromTaskID: nil,
        carriedFromSessionName: nil,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}
