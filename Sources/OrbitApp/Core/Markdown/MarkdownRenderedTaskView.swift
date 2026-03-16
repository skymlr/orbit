import Foundation
import SwiftUI

struct MarkdownRenderedTaskView: View {
    let markdown: String
    var onTaskLineToggle: ((Int) -> Void)? = nil

    var body: some View {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, line in
                lineView(line: line, lineIndex: lineIndex)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lineView(line: String, lineIndex: Int) -> some View {
        if let checklist = parseChecklistLine(line) {
            checklistLineRow(checklist, lineIndex: lineIndex)
        } else if let heading = parseHeadingLine(line) {
            headingLineRow(heading)
        } else if let unordered = parseUnorderedListLine(line) {
            listLineRow(
                marker: "•",
                text: unordered.text,
                indentation: unordered.indentation
            )
        } else if let ordered = parseOrderedListLine(line) {
            listLineRow(
                marker: "\(ordered.number).",
                text: ordered.text,
                indentation: ordered.indentation
            )
        } else if line.isEmpty {
            Text(" ")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(MarkdownAttributedRenderer.renderAttributed(markdown: line))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func headingLineRow(_ heading: HeadingLine) -> some View {
        Text(MarkdownAttributedRenderer.renderAttributed(markdown: heading.text.isEmpty ? " " : heading.text))
            .modifier(OrbitMarkdownHeadingFontModifier(level: heading.level))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, indentationWidth(for: heading.indentation))
    }

    @ViewBuilder
    private func listLineRow(marker: String, text: String, indentation: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .orbitFont(.body, weight: .semibold)
                .foregroundStyle(.secondary)

            Text(MarkdownAttributedRenderer.renderAttributed(markdown: text.isEmpty ? " " : text))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, indentationWidth(for: indentation))
    }

    @ViewBuilder
    private func checklistLineRow(_ checklist: ChecklistLine, lineIndex: Int) -> some View {
        if let onTaskLineToggle {
            Button {
                onTaskLineToggle(lineIndex)
            } label: {
                checklistLineContent(checklist)
            }
            .buttonStyle(.plain)
            .help(checklist.isChecked ? "Uncheck checklist item" : "Check checklist item")
        } else {
            checklistLineContent(checklist)
        }
    }

    private func checklistLineContent(_ checklist: ChecklistLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: checklist.isChecked ? "checkmark.square.fill" : "square")
                .orbitFont(.body, weight: .semibold)
                .foregroundStyle(checklist.isChecked ? OrbitTheme.Palette.completionGreen : .secondary)

            Text(MarkdownAttributedRenderer.renderAttributed(markdown: checklist.text.isEmpty ? " " : checklist.text))
                .frame(maxWidth: .infinity, alignment: .leading)
                .strikethrough(checklist.isChecked, color: .secondary)
                .opacity(checklist.isChecked ? 0.72 : 1)
        }
        .padding(.leading, indentationWidth(for: checklist.indentation))
    }

    private func indentationWidth(for indentation: String) -> CGFloat {
        let columns = indentation.reduce(0) { partialResult, character in
            partialResult + (character == "\t" ? 4 : 1)
        }
        return CGFloat(columns) * 6
    }

    private func parseHeadingLine(_ line: String) -> HeadingLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.headingRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let marker = substring(line, match.range(at: 2)),
              let text = substring(line, match.range(at: 3))
        else {
            return nil
        }

        return HeadingLine(
            level: min(max(marker.count, 1), 6),
            indentation: indentation,
            text: text
        )
    }

    private func parseChecklistLine(_ line: String) -> ChecklistLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.checklistRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let marker = substring(line, match.range(at: 3)),
              let text = substring(line, match.range(at: 4))
        else {
            return nil
        }

        return ChecklistLine(
            indentation: indentation,
            isChecked: marker.lowercased() == "x",
            text: text
        )
    }

    private func parseUnorderedListLine(_ line: String) -> ListLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.unorderedListRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let text = substring(line, match.range(at: 3))
        else {
            return nil
        }

        return ListLine(indentation: indentation, text: text)
    }

    private func parseOrderedListLine(_ line: String) -> OrderedListLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.orderedListRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let number = substring(line, match.range(at: 2)),
              let text = substring(line, match.range(at: 4))
        else {
            return nil
        }

        return OrderedListLine(indentation: indentation, number: number, text: text)
    }

    private func substring(_ line: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound else { return nil }
        guard let swiftRange = Range(range, in: line) else { return nil }
        return String(line[swiftRange])
    }

    private struct HeadingLine {
        let level: Int
        let indentation: String
        let text: String
    }

    private struct ListLine {
        let indentation: String
        let text: String
    }

    private struct ChecklistLine {
        let indentation: String
        let isChecked: Bool
        let text: String
    }

    private struct OrderedListLine {
        let indentation: String
        let number: String
        let text: String
    }

    private static let headingRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)(#{1,6})\s+(.*)$"#
    )

    private static let unorderedListRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+])\s+(.*)$"#
    )

    private static let checklistRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+])\s+\[( |x|X)\]\s+(.*)$"#
    )

    private static let orderedListRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)(\d+)([.)])\s+(.*)$"#
    )
}

private struct OrbitMarkdownHeadingFontModifier: ViewModifier {
    let level: Int

    func body(content: Content) -> some View {
        switch level {
        case 1:
            content.orbitFont(.title3, weight: .bold)
        case 2:
            content.orbitFont(.headline, weight: .semibold)
        default:
            content.orbitFont(.subheadline, weight: .semibold)
        }
    }
}
