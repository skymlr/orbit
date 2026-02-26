import Foundation
import Testing
@testable import OrbitApp

struct CaptureParserTests {
    @Test
    func parsesPrefixedTodoCapture() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let result = CaptureInputParser.parse(
            "@todo Test API timeout fallback",
            timestamp: timestamp,
            id: UUID()
        )

        #expect(result?.type == .todo)
        #expect(result?.content == "Test API timeout fallback")
    }

    @Test
    func defaultsToNoteWithoutPrefix() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let result = CaptureInputParser.parse(
            "Remember to follow up after standup",
            timestamp: timestamp,
            id: UUID()
        )

        #expect(result?.type == .note)
        #expect(result?.content == "Remember to follow up after standup")
    }
}
