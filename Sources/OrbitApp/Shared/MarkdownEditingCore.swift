import Foundation

enum MarkdownFormatAction: String, CaseIterable, Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case heading1
    case heading2
    case heading3
    case bulletList
    case numberedList
    case taskList

    var iconName: String {
        switch self {
        case .bold:
            return "bold"
        case .italic:
            return "italic"
        case .underline:
            return "underline"
        case .strikethrough:
            return "strikethrough"
        case .heading1:
            return "textformat.size.larger"
        case .heading2:
            return "textformat.size"
        case .heading3:
            return "textformat.size.smaller"
        case .bulletList:
            return "list.bullet"
        case .numberedList:
            return "list.number"
        case .taskList:
            return "checklist"
        }
    }

    var title: String {
        switch self {
        case .bold:
            return "Bold"
        case .italic:
            return "Italic"
        case .underline:
            return "Underline"
        case .strikethrough:
            return "Strikethrough"
        case .heading1:
            return "Heading 1"
        case .heading2:
            return "Heading 2"
        case .heading3:
            return "Heading 3"
        case .bulletList:
            return "Bulleted List"
        case .numberedList:
            return "Numbered List"
        case .taskList:
            return "Task List"
        }
    }
}

struct MarkdownTaskLine: Identifiable, Equatable, Sendable {
    let id: Int
    let lineIndex: Int
    let isChecked: Bool
    let lineText: String
    let indentation: String
}

struct MarkdownEditorState: Equatable {
    var text: String
    var selectionRange: NSRange
    var isPreviewVisible: Bool

    init(
        text: String = "",
        selectionRange: NSRange = NSRange(location: 0, length: 0),
        isPreviewVisible: Bool = false
    ) {
        self.text = text
        self.selectionRange = selectionRange
        self.isPreviewVisible = isPreviewVisible
    }
}

enum MarkdownAttributedRenderer {
    static func renderAttributed(markdown: String) -> AttributedString {
        if let rendered = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            return rendered
        }
        return AttributedString(markdown)
    }
}

enum MarkdownEditingCore {
    static func apply(action: MarkdownFormatAction, to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        switch action {
        case .bold:
            return applyInline(marker: "**", text: text, selection: selection)
        case .italic:
            return applyInline(marker: "*", text: text, selection: selection)
        case .underline:
            return applyInline(marker: "__", text: text, selection: selection)
        case .strikethrough:
            return applyInline(marker: "~~", text: text, selection: selection)
        case .heading1:
            return applyHeading(level: 1, to: text, selection: selection)
        case .heading2:
            return applyHeading(level: 2, to: text, selection: selection)
        case .heading3:
            return applyHeading(level: 3, to: text, selection: selection)
        case .bulletList:
            return applyBulletedList(to: text, selection: selection)
        case .numberedList:
            return applyNumberedList(to: text, selection: selection)
        case .taskList:
            return applyTaskList(to: text, selection: selection)
        }
    }

    static func toggleTask(in markdown: String, lineIndex: Int) -> String {
        var lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.indices.contains(lineIndex) else {
            return markdown
        }
        guard let task = parseTaskLine(lines[lineIndex], lineIndex: lineIndex) else {
            return markdown
        }

        let marker = task.isChecked ? " " : "x"
        lines[lineIndex] = "\(task.indentation)- [\(marker)] \(task.lineText)"
        return lines.joined(separator: "\n")
    }

    static func taskLines(in markdown: String) -> [MarkdownTaskLine] {
        markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .enumerated()
            .compactMap { parseTaskLine($0.element, lineIndex: $0.offset) }
    }

    private static func applyInline(marker: String, text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        let ns = text as NSString
        let range = clamped(selection, maxLength: ns.length)
        let mutable = NSMutableString(string: text)

        if range.length > 0 {
            let selected = ns.substring(with: range)
            let replacement = "\(marker)\(selected)\(marker)"
            mutable.replaceCharacters(in: range, with: replacement)

            let markerLength = (marker as NSString).length
            let selectedLength = (selected as NSString).length
            return (mutable as String, NSRange(location: range.location + markerLength, length: selectedLength))
        }

        let template = "\(marker)text\(marker)"
        mutable.replaceCharacters(in: range, with: template)
        let markerLength = (marker as NSString).length
        return (mutable as String, NSRange(location: range.location + markerLength, length: 4))
    }

    private static func applyHeading(level: Int, to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        let headingPrefix = String(repeating: "#", count: level) + " "
        return applyToSelectedLines(text: text, selection: selection, emptyTextInsertion: headingPrefix) { line, _ in
            let indent = leadingIndent(in: line)
            var content = String(line.dropFirst(indent.count))
            if let range = content.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                content.removeSubrange(range)
            }
            return "\(indent)\(headingPrefix)\(content)"
        }
    }

    private static func applyBulletedList(to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        applyToSelectedLines(text: text, selection: selection, emptyTextInsertion: "- ") { line, _ in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }
            let (indent, content) = stripLinePrefix(line)
            return "\(indent)- \(content)"
        }
    }

    private static func applyNumberedList(to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        var index = 1
        return applyToSelectedLines(text: text, selection: selection, emptyTextInsertion: "1. ") { line, _ in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }
            let (indent, content) = stripLinePrefix(line)
            defer { index += 1 }
            return "\(indent)\(index). \(content)"
        }
    }

    private static func applyTaskList(to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        applyToSelectedLines(text: text, selection: selection, emptyTextInsertion: "- [ ] ") { line, _ in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }
            let (indent, content) = stripLinePrefix(line)
            return "\(indent)- [ ] \(content)"
        }
    }

    private static func applyToSelectedLines(
        text: String,
        selection: NSRange,
        emptyTextInsertion: String,
        transform: (String, Int) -> String
    ) -> (text: String, selection: NSRange) {
        let ns = text as NSString
        let clampedSelection = clamped(selection, maxLength: ns.length)

        guard ns.length > 0 else {
            return (emptyTextInsertion, NSRange(location: (emptyTextInsertion as NSString).length, length: 0))
        }

        let lineRange = selectedLineRange(in: ns, selection: clampedSelection)
        let selectedText = ns.substring(with: lineRange)
        var lines = selectedText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for lineIndex in lines.indices {
            lines[lineIndex] = transform(lines[lineIndex], lineIndex)
        }

        let replacement = lines.joined(separator: "\n")
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: lineRange, with: replacement)

        return (
            mutable as String,
            NSRange(location: lineRange.location, length: (replacement as NSString).length)
        )
    }

    private static func selectedLineRange(in text: NSString, selection: NSRange) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }

        let startLocation = min(max(selection.location, 0), max(text.length - 1, 0))
        let startLine = text.lineRange(for: NSRange(location: startLocation, length: 0))

        if selection.length == 0 {
            return startLine
        }

        let rawEnd = selection.location + selection.length - 1
        let endLocation = min(max(rawEnd, 0), max(text.length - 1, 0))
        let endLine = text.lineRange(for: NSRange(location: endLocation, length: 0))

        let lowerBound = startLine.location
        let upperBound = endLine.location + endLine.length
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    private static func clamped(_ range: NSRange, maxLength: Int) -> NSRange {
        let location = min(max(range.location, 0), maxLength)
        let length = min(max(range.length, 0), maxLength - location)
        return NSRange(location: location, length: length)
    }

    private static func leadingIndent(in line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    private static func stripLinePrefix(_ line: String) -> (String, String) {
        let indent = leadingIndent(in: line)
        var content = String(line.dropFirst(indent.count))

        if let range = content.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
            content.removeSubrange(range)
        }
        if let range = content.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            content.removeSubrange(range)
        }
        if let range = content.range(of: #"^- \[[ xX]\]\s*"#, options: .regularExpression) {
            content.removeSubrange(range)
            return (indent, content)
        }
        if content.hasPrefix("- ") {
            content = String(content.dropFirst(2))
        }

        return (indent, content)
    }

    private static func parseTaskLine(_ line: String, lineIndex: Int) -> MarkdownTaskLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard
            let match = taskLineRegex.firstMatch(in: line, options: [], range: range),
            match.numberOfRanges == 4
        else {
            return nil
        }

        let nsLine = line as NSString
        let indentation = nsLine.substring(with: match.range(at: 1))
        let marker = nsLine.substring(with: match.range(at: 2)).lowercased()
        let text = nsLine.substring(with: match.range(at: 3))

        return MarkdownTaskLine(
            id: lineIndex,
            lineIndex: lineIndex,
            isChecked: marker == "x",
            lineText: text,
            indentation: indentation
        )
    }

    private static let taskLineRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)- \[([ xX])\]\s*(.*)$"#,
        options: []
    )
}
