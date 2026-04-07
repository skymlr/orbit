import Foundation

enum SessionTaskNavigationDirection: Equatable {
    case previous
    case next
}

#if os(macOS)
@preconcurrency import AppKit

enum SessionTaskTabNavigation {
    static let tabKeyCode: UInt16 = 48

    static func direction(
        for keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        isEditableTextInputFocused: Bool,
        targetsObservedWindow: Bool
    ) -> SessionTaskNavigationDirection? {
        guard targetsObservedWindow else { return nil }
        guard !isEditableTextInputFocused else { return nil }
        guard keyCode == tabKeyCode else { return nil }

        let deviceIndependentModifiers = modifiers.intersection(.deviceIndependentFlagsMask)
        guard deviceIndependentModifiers.subtracting(.shift).isEmpty else { return nil }

        return deviceIndependentModifiers.contains(.shift) ? .previous : .next
    }
}
#endif
