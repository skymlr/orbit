import Foundation
import Testing
@testable import OrbitApp

struct SessionStoreTests {
    @Test
    func markdownRenderMatchesExpectedSections() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let session = Session(
            mode: .coding,
            startedAt: date,
            endedAt: nil,
            items: [
                CapturedItem(
                    id: UUID(),
                    content: "Refactor auth error path",
                    mode: .coding,
                    timestamp: date,
                    type: .next
                )
            ]
        )

        let markdown = SessionMarkdownCodec.render(session)

        #expect(markdown.contains("# Session: Coding -"))
        #expect(markdown.contains("## Captured Items"))
        #expect(markdown.contains("### "))
        #expect(markdown.contains("@next"))
        #expect(markdown.contains("Refactor auth error path"))
    }
}
