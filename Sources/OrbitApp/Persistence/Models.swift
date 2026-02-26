import Foundation
import SQLiteData
import StructuredQueries

@Table struct SessionCategory: Identifiable, Sendable {
    let id: UUID
    var name = ""
    var normalizedName = ""
    var colorHex: String = FocusDefaults.defaultCategoryColorHex
}

@Table struct FocusSession: Identifiable, Sendable {
    let id: UUID
    var name = ""
    var categoryID: SessionCategory.ID
    var startedAt: Date = Date()
    var endedAt: Date?
    var endedReason: String?
}

@Table struct SessionNote: Identifiable, Sendable {
    let id: UUID
    var sessionID: FocusSession.ID
    var text = ""
    var priority = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

@Table struct SessionNoteTag: Identifiable, Sendable {
    let id: UUID
    var noteID: SessionNote.ID
    var name = ""
    var normalizedName = ""
}
