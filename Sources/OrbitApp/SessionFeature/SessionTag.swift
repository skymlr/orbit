import Foundation

struct SessionTag: Equatable, Hashable, Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
}

extension SessionTag {
    static let builtIns: [SessionTag] = [
        SessionTag(id: UUID(uuidString: "A4F6E7E2-8AC7-4A10-81C1-FA7B43E3CE01")!, name: "coding", isBuiltIn: true),
        SessionTag(id: UUID(uuidString: "A4F6E7E2-8AC7-4A10-81C1-FA7B43E3CE02")!, name: "researching", isBuiltIn: true),
        SessionTag(id: UUID(uuidString: "A4F6E7E2-8AC7-4A10-81C1-FA7B43E3CE03")!, name: "email", isBuiltIn: true),
        SessionTag(id: UUID(uuidString: "A4F6E7E2-8AC7-4A10-81C1-FA7B43E3CE04")!, name: "meeting", isBuiltIn: true),
    ]

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var displayName: String {
        name.capitalized
    }
}
