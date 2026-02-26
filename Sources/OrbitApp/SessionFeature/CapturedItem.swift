import Foundation
import Parsing

enum ItemType: String, CaseIterable, Codable, Equatable, Sendable {
    case todo
    case next
    case note
    case link

    var prefix: String {
        "@\(rawValue)"
    }
}

struct CapturedItem: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    var content: String
    var mode: FocusMode
    var timestamp: Date
    var type: ItemType
}

enum CaptureInputParser {
    static func parse(
        _ rawInput: String,
        mode: FocusMode,
        timestamp: Date,
        id: UUID
    ) -> CapturedItem? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var input = trimmed[...]
        let type: ItemType

        if let parsedType = try? ItemTypePrefixParser().parse(&input) {
            type = parsedType
            while input.first?.isWhitespace == true {
                input.removeFirst()
            }
        } else {
            type = .note
        }

        let content = String(input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }

        return CapturedItem(
            id: id,
            content: content,
            mode: mode,
            timestamp: timestamp,
            type: type
        )
    }
}

private struct ItemTypePrefixParser: Parser {
    var body: some Parser<Substring, ItemType> {
        OneOf {
            "@todo".map { ItemType.todo }
            "@next".map { ItemType.next }
            "@note".map { ItemType.note }
            "@link".map { ItemType.link }
        }
    }
}
