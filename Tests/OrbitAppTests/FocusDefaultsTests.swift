import Foundation
import Testing
@testable import OrbitApp

struct FocusDefaultsTests {
    @Test
    func defaultSessionNameUsesMorning() {
        #expect(FocusDefaults.defaultSessionName(startedAt: dateAtLocalHour(9)) == "Morning Session")
    }

    @Test
    func defaultSessionNameUsesAfternoon() {
        #expect(FocusDefaults.defaultSessionName(startedAt: dateAtLocalHour(14)) == "Afternoon Session")
    }

    @Test
    func defaultSessionNameUsesEvening() {
        #expect(FocusDefaults.defaultSessionName(startedAt: dateAtLocalHour(18)) == "Evening Session")
    }

    @Test
    func defaultSessionNameUsesEveningForNightHours() {
        #expect(FocusDefaults.defaultSessionName(startedAt: dateAtLocalHour(23)) == "Evening Session")
        #expect(FocusDefaults.defaultSessionName(startedAt: dateAtLocalHour(3)) == "Evening Session")
    }

    @Test
    func nextSessionBoundaryAtMorningCutoff() {
        let date = dateAtLocalTime(hour: 11, minute: 59)
        let boundary = FocusDefaults.nextSessionBoundary(after: date)
        #expect(isSameLocalDay(boundary, as: date))
        #expect(localHour(boundary) == 12)
        #expect(localMinute(boundary) == 0)
    }

    @Test
    func nextSessionBoundaryAtAfternoonCutoff() {
        let date = dateAtLocalTime(hour: 16, minute: 59)
        let boundary = FocusDefaults.nextSessionBoundary(after: date)
        #expect(isSameLocalDay(boundary, as: date))
        #expect(localHour(boundary) == 17)
        #expect(localMinute(boundary) == 0)
    }

    @Test
    func nextSessionBoundaryFromLateNightGoesToNextMorning() {
        let date = dateAtLocalTime(hour: 23, minute: 30)
        let boundary = FocusDefaults.nextSessionBoundary(after: date)
        #expect(localHour(boundary) == 5)
        #expect(localMinute(boundary) == 0)
        #expect(!isSameLocalDay(boundary, as: date))
    }

    @Test
    func nextSessionBoundaryFromPreMorningGoesToFiveAM() {
        let date = dateAtLocalTime(hour: 4, minute: 59)
        let boundary = FocusDefaults.nextSessionBoundary(after: date)
        #expect(isSameLocalDay(boundary, as: date))
        #expect(localHour(boundary) == 5)
        #expect(localMinute(boundary) == 0)
    }

    private func dateAtLocalHour(_ hour: Int) -> Date {
        dateAtLocalTime(hour: hour, minute: 0)
    }

    private func dateAtLocalTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let day = calendar.startOfDay(for: base)
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
    }

    private func isSameLocalDay(_ lhs: Date, as rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private func localHour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private func localMinute(_ date: Date) -> Int {
        Calendar.current.component(.minute, from: date)
    }
}
