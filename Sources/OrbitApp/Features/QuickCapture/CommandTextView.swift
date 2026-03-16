import AppKit
import Foundation

final class CommandTextView: NSTextView {
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
    var onMoveToNextField: (() -> Void)?
    var onMoveToPreviousField: (() -> Void)?

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                insertNewlineIgnoringFieldEditor(nil)
            } else if handleListEnter() {
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

    private func handleListEnter() -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else { return false }

        let source = string as NSString
        guard selection.location <= source.length else { return false }

        let lineRange = source.lineRange(for: NSRange(location: selection.location, length: 0))
        let lineString = source.substring(with: lineRange)
        let contentLength = lineStringLengthWithoutTrailingNewlines(lineString)
        let lineContentRange = NSRange(location: lineRange.location, length: contentLength)

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
