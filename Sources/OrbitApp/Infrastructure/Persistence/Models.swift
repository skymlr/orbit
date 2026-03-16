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
    var startedAt: Date = Date()
    var endedAt: Date?
    var endedReason: String?
}

@Table struct SessionTask: Identifiable, Sendable {
    let id: UUID
    var sessionID: FocusSession.ID
    var markdown = ""
    var priority = ""
    var completedAt: Date?
    var carriedFromTaskID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

@Table struct SessionTaskCategory: Identifiable, Sendable {
    let id: UUID
    var taskID: SessionTask.ID
    var categoryID: SessionCategory.ID
}
