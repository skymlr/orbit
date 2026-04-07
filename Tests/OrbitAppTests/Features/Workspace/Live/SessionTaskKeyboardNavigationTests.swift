import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

#if os(macOS)
import AppKit

struct SessionTaskKeyboardNavigationTests {
    @Test
    func tabMovesToNextTask() {
        let direction = SessionTaskTabNavigation.direction(
            for: SessionTaskTabNavigation.tabKeyCode,
            modifiers: [],
            isEditableTextInputFocused: false,
            targetsObservedWindow: true
        )

        #expect(direction == .next)
    }

    @Test
    func shiftTabMovesToPreviousTask() {
        let direction = SessionTaskTabNavigation.direction(
            for: SessionTaskTabNavigation.tabKeyCode,
            modifiers: [.shift],
            isEditableTextInputFocused: false,
            targetsObservedWindow: true
        )

        #expect(direction == .previous)
    }

    @Test
    func modifiedTabDoesNotOverrideSystemShortcuts() {
        let direction = SessionTaskTabNavigation.direction(
            for: SessionTaskTabNavigation.tabKeyCode,
            modifiers: [.command],
            isEditableTextInputFocused: false,
            targetsObservedWindow: true
        )

        #expect(direction == nil)
    }

    @Test
    func tabDoesNotFireWhileEditingText() {
        let direction = SessionTaskTabNavigation.direction(
            for: SessionTaskTabNavigation.tabKeyCode,
            modifiers: [],
            isEditableTextInputFocused: true,
            targetsObservedWindow: true
        )

        #expect(direction == nil)
    }

    @Test
    func tabDoesNotFireForOtherWindows() {
        let direction = SessionTaskTabNavigation.direction(
            for: SessionTaskTabNavigation.tabKeyCode,
            modifiers: [],
            isEditableTextInputFocused: false,
            targetsObservedWindow: false
        )

        #expect(direction == nil)
    }
}
#endif
