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
    func defaultSessionNameUsesNight() {
        #expect(FocusDefaults.defaultSessionName(startedAt: dateAtLocalHour(23)) == "Night Session")
        #expect(FocusDefaults.defaultSessionName(startedAt: dateAtLocalHour(3)) == "Night Session")
    }

    private func dateAtLocalHour(_ hour: Int) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        return calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
    }
}
