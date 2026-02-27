import AppKit
import SwiftUI

struct MarkdownSourceTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange
    @Binding var isFocused: Bool

    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = CommandTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 80)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = context.coordinator
        textView.string = text
        textView.setSelectedRange(selectionRange)
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel

        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        guard let textView = nsView.documentView as? CommandTextView else { return }
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel

        if textView.string != text {
            textView.string = text
        }

        let currentSelection = textView.selectedRange()
        if currentSelection != selectionRange {
            textView.setSelectedRange(selectionRange)
        }

        guard let window = textView.window else { return }

        if isFocused, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        } else if !isFocused, window.firstResponder === textView {
            window.makeFirstResponder(nil)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownSourceTextView

        init(parent: MarkdownSourceTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.selectionRange = textView.selectedRange()
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }
    }
}

private final class CommandTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                insertNewlineIgnoringFieldEditor(nil)
            } else {
                onSubmit?()
            }
            return
        }

        if selector == #selector(cancelOperation(_:)) {
            onCancel?()
            return
        }

        super.doCommand(by: selector)
    }
}
