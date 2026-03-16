import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct MarkdownEditingCoreTests {
    @Test
    func boldActionWrapsSelectedText() {
        let result = MarkdownEditingCore.apply(
            action: .bold,
            to: "launch window",
            selection: NSRange(location: 0, length: 6)
        )

        #expect(result.text == "**launch** window")
        #expect(result.selection == NSRange(location: 2, length: 6))
    }

    @Test
    func inlineActionWithoutSelectionInsertsTemplate() {
        let result = MarkdownEditingCore.apply(
            action: .italic,
            to: "",
            selection: NSRange(location: 0, length: 0)
        )

        #expect(result.text == "*text*")
        #expect(result.selection == NSRange(location: 1, length: 4))
    }

    @Test
    func headingActionAppliesToSelectedLines() {
        let result = MarkdownEditingCore.apply(
            action: .heading2,
            to: "alpha\nbeta",
            selection: NSRange(location: 0, length: 10)
        )

        #expect(result.text == "## alpha\n## beta")
    }

    @Test
    func listActionsNormalizeExistingPrefixes() {
        let bulleted = MarkdownEditingCore.apply(
            action: .bulletList,
            to: "1. alpha\n2. beta",
            selection: NSRange(location: 0, length: 16)
        )
        #expect(bulleted.text == "- alpha\n- beta")

        let numbered = MarkdownEditingCore.apply(
            action: .numberedList,
            to: "- alpha\n- beta",
            selection: NSRange(location: 0, length: 14)
        )
        #expect(numbered.text == "1. alpha\n2. beta")
    }

    @Test
    func taskListActionBuildsUncheckedTasks() {
        let result = MarkdownEditingCore.apply(
            action: .taskList,
            to: "alpha\nbeta",
            selection: NSRange(location: 0, length: 10)
        )

        #expect(result.text == "- [ ] alpha\n- [ ] beta")
    }

    @Test
    func rendererFallsBackForInvalidMarkdown() {
        let rendered = MarkdownAttributedRenderer.renderAttributed(markdown: "[broken(")
        #expect(!rendered.characters.isEmpty)
    }
}
