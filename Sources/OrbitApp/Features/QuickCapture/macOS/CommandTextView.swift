import Foundation

#if os(macOS)
import AppKit

final class CommandTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onMoveToNextField: (() -> Void)?
    var onMoveToPreviousField: (() -> Void)?

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                insertNewlineIgnoringFieldEditor(nil)
            } else if let command = MarkdownTextCommandHandler.handleReturn(
                in: string,
                selection: selectedRange()
            ) {
                string = command.text
                setSelectedRange(command.selection)
                didChangeText()
            } else {
                onSubmit?()
            }
            return
        }

        if selector == #selector(cancelOperation(_:)) {
            onCancel?()
            return
        }

        if selector == #selector(insertTab(_:)) {
            if let onMoveToNextField {
                onMoveToNextField()
                return
            }
        }

        if selector == #selector(insertBacktab(_:)) {
            if let onMoveToPreviousField {
                onMoveToPreviousField()
                return
            }
        }

        super.doCommand(by: selector)
    }
}
#endif
