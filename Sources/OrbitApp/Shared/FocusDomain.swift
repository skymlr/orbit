import Foundation

enum NotePriority: String, CaseIterable, Codable, Equatable, Sendable {
    case none
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum SessionEndReason: String, Codable, Equatable, Sendable {
    case manual
    case inactivity
    case appClosed
}

enum HotkeyKind: String, Equatable, Sendable {
    case startSession
    case capture
}

struct HotkeySettings: Equatable, Sendable {
    var startShortcut: String
    var captureShortcut: String
    var captureNextPriorityShortcut: String

    static let `default` = HotkeySettings(
        startShortcut: "ctrl+option+cmd+k",
        captureShortcut: "ctrl+option+cmd+j",
        captureNextPriorityShortcut: "cmd+."
    )
}

struct SessionCategoryRecord: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var normalizedName: String
    var colorHex: String
}

struct NoteCategoryRecord: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var colorHex: String
}

struct FocusNoteRecord: Equatable, Identifiable, Sendable {
    var id: UUID
    var sessionID: UUID
    var categories: [NoteCategoryRecord]
    var text: String
    var priority: NotePriority
    var createdAt: Date
    var updatedAt: Date
}

struct FocusSessionRecord: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var endedReason: SessionEndReason?
    var notes: [FocusNoteRecord]

    var isActive: Bool {
        endedAt == nil
    }
}

enum FocusDefaults {
    static let uncategorizedCategoryID = UUID(uuidString: "C8B3B4CC-2928-4A84-9C3B-EB253E9D0001")!
    static let uncategorizedCategoryName = "uncategorized"
    static let uncategorizedCategoryColorHex = "#00B5FF"
    static let defaultCategoryColorHex = "#58B5FF"
    static let categoryColorOptions: [String] = [
        "#00B5FF",
        "#58B5FF",
        "#38D39F",
        "#7ED957",
        "#F2C94C",
        "#FF9F1C",
        "#FF6B6B",
        "#EF476F",
        "#B388FF",
        "#8D99AE",
    ]

    static func defaultSessionName(startedAt: Date) -> String {
        let day = Calendar.current.component(.day, from: startedAt)
        let year = Calendar.current.component(.year, from: startedAt)
        let month = sessionNameMonthFormatter.string(from: startedAt)
        let time = sessionNameTimeFormatter.string(from: startedAt)
        return "\(month) \(day)\(ordinalSuffix(for: day)), \(year) @ \(time)"
    }

    static func normalizedCategoryName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedCategoryColorHex(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let noPrefix = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed

        guard noPrefix.count == 6, noPrefix.allSatisfy(\.isHexDigit) else {
            return defaultCategoryColorHex
        }

        return "#\(noPrefix.uppercased())"
    }

    static func markdownFileName(for session: FocusSessionRecord) -> String {
        "\(exportFileFormatter.string(from: session.startedAt))-\(session.id.uuidString.lowercased()).md"
    }

    private static func ordinalSuffix(for day: Int) -> String {
        let twoDigits = day % 100
        if (11...13).contains(twoDigits) {
            return "th"
        }

        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private static let sessionNameMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static let sessionNameTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "h:mma"
        return formatter
    }()

    private static let exportFileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}
