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

    static let `default` = HotkeySettings(
        startShortcut: "cmd+shift+s",
        captureShortcut: "cmd+shift+o"
    )
}

struct SessionCategoryRecord: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var normalizedName: String
}

struct FocusNoteRecord: Equatable, Identifiable, Sendable {
    var id: UUID
    var sessionID: UUID
    var text: String
    var priority: NotePriority
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
}

struct FocusSessionRecord: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var categoryID: UUID
    var categoryName: String
    var startedAt: Date
    var endedAt: Date?
    var endedReason: SessionEndReason?
    var notes: [FocusNoteRecord]

    var isActive: Bool {
        endedAt == nil
    }
}

enum FocusDefaults {
    static let focusCategoryID = UUID(uuidString: "C8B3B4CC-2928-4A84-9C3B-EB253E9D0001")!
    static let focusCategoryName = "focus"

    static func defaultSessionName(startedAt: Date) -> String {
        sessionNameFormatter.string(from: startedAt)
    }

    static func normalizedCategoryName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedTag(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func parseTagInput(_ input: String) -> [String] {
        var seen = Set<String>()
        var values: [String] = []

        for component in input.split(separator: ",") {
            let normalized = normalizedTag(String(component))
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            values.append(normalized)
        }

        return values
    }

    static func markdownFileName(for session: FocusSessionRecord) -> String {
        "\(exportFileFormatter.string(from: session.startedAt))-\(session.id.uuidString.lowercased()).md"
    }

    private static let sessionNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
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
