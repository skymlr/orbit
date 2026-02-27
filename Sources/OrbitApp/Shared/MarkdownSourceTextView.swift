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

        context.coordinator.isSynchronizingFromSwiftUI = true
        defer {
            context.coordinator.isSynchronizingFromSwiftUI = false
        }

        if textView.string != text {
            textView.string = text
        }

        let currentSelection = textView.selectedRange()
        if currentSelection != selectionRange {
            textView.setSelectedRange(selectionRange)
        }

        context.coordinator.scheduleFocusUpdate(for: textView, isFocused: isFocused)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownSourceTextView
        var isSynchronizingFromSwiftUI = false

        init(parent: MarkdownSourceTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isSynchronizingFromSwiftUI else { return }
            let updatedText = textView.string
            guard parent.text != updatedText else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard !self.isSynchronizingFromSwiftUI else { return }
                guard self.parent.text != updatedText else { return }
                self.parent.text = updatedText
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            updateFocusState(isFocused: true)
        }

        func textDidEndEditing(_ notification: Notification) {
            updateFocusState(isFocused: false)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isSynchronizingFromSwiftUI else { return }
            if textView.window?.firstResponder === textView {
                updateFocusState(isFocused: true)
            }
            let newSelection = textView.selectedRange()
            guard parent.selectionRange != newSelection else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard !self.isSynchronizingFromSwiftUI else { return }
                guard self.parent.selectionRange != newSelection else { return }
                self.parent.selectionRange = newSelection
            }
        }

        func scheduleFocusUpdate(for textView: NSTextView, isFocused: Bool) {
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                guard let window = textView.window else { return }

                if isFocused, window.firstResponder !== textView {
                    window.makeFirstResponder(textView)
                } else if !isFocused, window.firstResponder === textView {
                    window.makeFirstResponder(nil)
                }
            }
        }

        private func updateFocusState(isFocused: Bool) {
            guard !isSynchronizingFromSwiftUI else { return }
            guard parent.isFocused != isFocused else { return }
            parent.isFocused = isFocused
        }
    }
}

private final class CommandTextView: NSTextView {
    private struct ListContinuation {
        enum Kind {
            case unordered(bullet: String)
            case ordered(number: Int, separator: String)
            case task(bullet: String)
        }

        let lineContentRange: NSRange
        let kind: Kind
        let indentation: String
        let hasContent: Bool
    }

    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                insertNewlineIgnoringFieldEditor(nil)
            } else if handleListEnter() {
                // Handled as markdown list continuation or list exit.
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

    private func handleListEnter() -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else { return false }

        let source = string as NSString
        guard selection.location <= source.length else { return false }

        let lineRange = source.lineRange(for: NSRange(location: selection.location, length: 0))
        let lineString = source.substring(with: lineRange)
        let contentLength = lineStringLengthWithoutTrailingNewlines(lineString)
        let lineContentRange = NSRange(location: lineRange.location, length: contentLength)

        // Keep "Enter saves" behavior outside list editing scenarios.
        guard selection.location == lineContentRange.location + lineContentRange.length else {
            return false
        }

        let lineContent = source.substring(with: lineContentRange)
        guard let continuation = parseListContinuation(
            lineContentRange: lineContentRange,
            lineContent: lineContent
        ) else {
            return false
        }

        if continuation.hasContent {
            let marker = continuationMarker(for: continuation)
            insertText("\n\(marker)", replacementRange: selection)
        } else {
            guard shouldChangeText(in: continuation.lineContentRange, replacementString: "") else {
                return true
            }
            textStorage?.replaceCharacters(in: continuation.lineContentRange, with: "")
            didChangeText()
            setSelectedRange(NSRange(location: continuation.lineContentRange.location, length: 0))
        }

        return true
    }

    private func parseListContinuation(
        lineContentRange: NSRange,
        lineContent: String
    ) -> ListContinuation? {
        let fullRange = NSRange(location: 0, length: (lineContent as NSString).length)

        if let match = taskRegex.firstMatch(in: lineContent, options: [], range: fullRange),
           let indentation = substring(in: lineContent, range: match.range(at: 1)),
           let bullet = substring(in: lineContent, range: match.range(at: 2)),
           let content = substring(in: lineContent, range: match.range(at: 3)) {
            return ListContinuation(
                lineContentRange: lineContentRange,
                kind: .task(bullet: bullet),
                indentation: indentation,
                hasContent: !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }

        if let match = unorderedRegex.firstMatch(in: lineContent, options: [], range: fullRange),
           let indentation = substring(in: lineContent, range: match.range(at: 1)),
           let bullet = substring(in: lineContent, range: match.range(at: 2)),
           let content = substring(in: lineContent, range: match.range(at: 3)) {
            return ListContinuation(
                lineContentRange: lineContentRange,
                kind: .unordered(bullet: bullet),
                indentation: indentation,
                hasContent: !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }

        if let match = orderedRegex.firstMatch(in: lineContent, options: [], range: fullRange),
           let indentation = substring(in: lineContent, range: match.range(at: 1)),
           let numberText = substring(in: lineContent, range: match.range(at: 2)),
           let separator = substring(in: lineContent, range: match.range(at: 3)),
           let content = substring(in: lineContent, range: match.range(at: 4)) {
            let number = Int(numberText) ?? 1
            return ListContinuation(
                lineContentRange: lineContentRange,
                kind: .ordered(number: number, separator: separator),
                indentation: indentation,
                hasContent: !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }

        return nil
    }

    private func continuationMarker(for continuation: ListContinuation) -> String {
        switch continuation.kind {
        case let .unordered(bullet):
            return "\(continuation.indentation)\(bullet) "
        case let .ordered(number, separator):
            return "\(continuation.indentation)\(max(number + 1, 1))\(separator) "
        case let .task(bullet):
            return "\(continuation.indentation)\(bullet) [ ] "
        }
    }

    private func lineStringLengthWithoutTrailingNewlines(_ line: String) -> Int {
        let string = line as NSString
        var length = string.length
        while length > 0 {
            let character = string.substring(with: NSRange(location: length - 1, length: 1))
            if character == "\n" || character == "\r" {
                length -= 1
            } else {
                break
            }
        }
        return length
    }

    private func substring(in source: String, range: NSRange) -> String? {
        guard range.location != NSNotFound else { return nil }
        guard let range = Range(range, in: source) else { return nil }
        return String(source[range])
    }

    private var unorderedRegex: NSRegularExpression {
        Self.unorderedRegex
    }

    private var orderedRegex: NSRegularExpression {
        Self.orderedRegex
    }

    private var taskRegex: NSRegularExpression {
        Self.taskRegex
    }

    private static let unorderedRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+])\s+(.*)$"#
    )

    private static let orderedRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)(\d+)([.)])\s+(.*)$"#
    )

    private static let taskRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+])\s+\[(?: |x|X)\]\s*(.*)$"#
    )
}
