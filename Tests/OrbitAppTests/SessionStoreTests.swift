import Foundation
import Testing
@testable import OrbitApp

struct SessionStoreTests {
    @Test
    func markdownRenderMatchesNewSessionStructure() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_003_600)

        let session = Session(
            title: "Focus",
            tags: [
                SessionTag.builtIns[0],
                SessionTag(id: UUID(), name: "deep-work", isBuiltIn: false),
            ],
            startedAt: start,
            endedAt: end,
            items: [
                CapturedItem(
                    id: UUID(),
                    content: "Refactor auth error path",
                    timestamp: start,
                    type: .next
                )
            ]
        )

        let markdown = SessionMarkdownCodec.render(session)

        #expect(markdown.contains("# Session: Focus -"))
        #expect(markdown.contains("Tags: coding, deep-work"))
        #expect(markdown.contains("Started:"))
        #expect(markdown.contains("Ended:"))
        #expect(markdown.contains("## Captured Items"))
        #expect(markdown.contains("@next"))
        #expect(markdown.contains("Refactor auth error path"))
    }

    @Test
    func parsesLegacyModeMarkdownAsBuiltInTag() throws {
        let markdown = """
        # Session: Coding - 2024-01-15 14:30

        ## Captured Items

        ### 14:32 - @todo
        Test edge case with null values
        """

        let parsed = try SessionMarkdownCodec.parse(
            markdown: markdown,
            fileURL: URL(fileURLWithPath: "/tmp/legacy.md")
        )

        #expect(parsed.title == "Focus")
        #expect(parsed.tags.contains(where: { $0.name == "coding" }))
        #expect(parsed.items.count == 1)
        #expect(parsed.items.first?.type == .todo)
        #expect(parsed.items.first?.content == "Test edge case with null values")
    }
}
