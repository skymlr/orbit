import Dependencies
import Foundation
import SQLiteData

struct FocusRepository: Sendable {
    var startSession: @Sendable (_ now: Date) async throws -> FocusSessionRecord
    var loadActiveSession: @Sendable () async throws -> FocusSessionRecord?
    var endSession: @Sendable (_ id: UUID, _ name: String?, _ reason: SessionEndReason, _ endedAt: Date) async throws -> FocusSessionRecord?
    var endSessionSync: @Sendable (_ id: UUID, _ name: String?, _ reason: SessionEndReason, _ endedAt: Date) throws -> Void

    var listSessions: @Sendable () async throws -> [FocusSessionRecord]
    var renameSession: @Sendable (_ id: UUID, _ name: String) async throws -> Void
    var deleteSession: @Sendable (_ id: UUID) async throws -> Void

    var listCategories: @Sendable () async throws -> [SessionCategoryRecord]
    var addCategory: @Sendable (_ name: String, _ colorHex: String) async throws -> SessionCategoryRecord?
    var renameCategory: @Sendable (_ id: UUID, _ name: String, _ colorHex: String) async throws -> Void
    var deleteCategory: @Sendable (_ id: UUID) async throws -> Void

    var createNote: @Sendable (_ sessionID: UUID, _ text: String, _ priority: NotePriority, _ categoryIDs: [UUID], _ now: Date) async throws -> FocusNoteRecord?
    var updateNote: @Sendable (_ noteID: UUID, _ text: String, _ priority: NotePriority, _ categoryIDs: [UUID], _ now: Date) async throws -> FocusNoteRecord?
    var deleteNote: @Sendable (_ noteID: UUID) async throws -> Void

    var exportSessionsMarkdown: @Sendable (_ sessionIDs: [UUID], _ directoryURL: URL) async throws -> [URL]
}

extension FocusRepository: DependencyKey {
    static var liveValue: FocusRepository {
        FocusRepository(
            startSession: { now in
                @Dependency(\.defaultDatabase) var database
                @Dependency(\.uuid) var uuid

                let sessionID = uuid()
                let name = FocusDefaults.defaultSessionName(startedAt: now)

                return try await database.write { db in
                    try FocusSession.insert {
                        ($0.id, $0.name, $0.startedAt, $0.endedAt, $0.endedReason)
                    } values: {
                        (sessionID, name, now, nil, nil)
                    }
                    .execute(db)

                    guard let session = try buildSessionRecord(db: db, sessionID: sessionID) else {
                        throw FocusRepositoryError.notFound
                    }
                    return session
                }
            },
            loadActiveSession: {
                @Dependency(\.defaultDatabase) var database

                return try await database.read { db in
                    let row = try FocusSession
                        .where { $0.endedAt.is(nil) }
                        .order { $0.startedAt.desc() }
                        .fetchOne(db)
                    guard let row else { return nil }
                    return try buildSessionRecord(db: db, sessionID: row.id)
                }
            },
            endSession: { id, name, reason, endedAt in
                @Dependency(\.defaultDatabase) var database

                return try await database.write { db in
                    let existing = try FocusSession.find(id).fetchOne(db)
                    guard let existing else { return nil }

                    let resolvedName = normalizedSessionName(name, fallbackDate: existing.startedAt)

                    try FocusSession.find(id).update {
                        $0.name = resolvedName
                        $0.endedAt = #bind(endedAt)
                        $0.endedReason = #bind(reason.rawValue)
                    }
                    .execute(db)

                    return try buildSessionRecord(db: db, sessionID: id)
                }
            },
            endSessionSync: { id, name, reason, endedAt in
                @Dependency(\.defaultDatabase) var database

                try database.write { db in
                    let existing = try FocusSession.find(id).fetchOne(db)
                    guard let existing else { return }

                    let resolvedName = normalizedSessionName(name, fallbackDate: existing.startedAt)

                    try FocusSession.find(id).update {
                        $0.name = resolvedName
                        $0.endedAt = #bind(endedAt)
                        $0.endedReason = #bind(reason.rawValue)
                    }
                    .execute(db)
                }
            },
            listSessions: {
                @Dependency(\.defaultDatabase) var database

                return try await database.read { db in
                    let rows = try FocusSession
                        .order { $0.startedAt.desc() }
                        .fetchAll(db)
                    return try rows.compactMap { try buildSessionRecord(db: db, sessionID: $0.id) }
                }
            },
            renameSession: { id, name in
                @Dependency(\.defaultDatabase) var database

                try await database.write { db in
                    let existing = try FocusSession.find(id).fetchOne(db)
                    guard let existing else { return }

                    let resolvedName = normalizedSessionName(name, fallbackDate: existing.startedAt)
                    try FocusSession.find(id).update {
                        $0.name = resolvedName
                    }
                    .execute(db)
                }
            },
            deleteSession: { id in
                @Dependency(\.defaultDatabase) var database

                try await database.write { db in
                    try FocusSession.find(id).delete().execute(db)
                }
            },
            listCategories: {
                @Dependency(\.defaultDatabase) var database

                return try await database.write { db in
                    let rows = try SessionCategory
                        .order(by: \.name)
                        .fetchAll(db)

                    return rows.map {
                        SessionCategoryRecord(
                            id: $0.id,
                            name: $0.name,
                            normalizedName: $0.normalizedName,
                            colorHex: FocusDefaults.normalizedCategoryColorHex($0.colorHex)
                        )
                    }
                }
            },
            addCategory: { name, colorHex in
                @Dependency(\.defaultDatabase) var database
                @Dependency(\.uuid) var uuid

                let normalized = FocusDefaults.normalizedCategoryName(name)
                guard !normalized.isEmpty else { return nil }
                let normalizedColor = FocusDefaults.normalizedCategoryColorHex(colorHex)

                return try await database.write { db in
                    if try SessionCategory.where({ $0.normalizedName.eq(normalized) }).fetchOne(db) != nil {
                        return nil
                    }

                    let id = uuid()
                    let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)

                    try SessionCategory.insert {
                        ($0.id, $0.name, $0.normalizedName, $0.colorHex)
                    } values: {
                        (id, displayName, normalized, normalizedColor)
                    }
                    .execute(db)

                    return SessionCategoryRecord(
                        id: id,
                        name: displayName,
                        normalizedName: normalized,
                        colorHex: normalizedColor
                    )
                }
            },
            renameCategory: { id, name, colorHex in
                @Dependency(\.defaultDatabase) var database

                let normalized = FocusDefaults.normalizedCategoryName(name)
                let normalizedColor = FocusDefaults.normalizedCategoryColorHex(colorHex)

                try await database.write { db in
                    guard !normalized.isEmpty else { return }

                    let conflict = try SessionCategory
                        .where { categories in categories.normalizedName.eq(normalized) }
                        .fetchOne(db)
                    if let conflict, conflict.id != id {
                        return
                    }

                    try SessionCategory.find(id).update {
                        $0.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        $0.normalizedName = normalized
                        $0.colorHex = normalizedColor
                    }
                    .execute(db)
                }
            },
            deleteCategory: { id in
                @Dependency(\.defaultDatabase) var database

                try await database.write { db in
                    try SessionNoteCategory.where { $0.categoryID.eq(id) }
                        .delete()
                        .execute(db)

                    try SessionCategory.find(id).delete().execute(db)
                }
            },
            createNote: { sessionID, text, priority, categoryIDs, now in
                @Dependency(\.defaultDatabase) var database
                @Dependency(\.uuid) var uuid

                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let noteID = uuid()

                return try await database.write { db in
                    if try FocusSession.find(sessionID).fetchOne(db) == nil {
                        return nil
                    }

                    let resolvedCategoryIDs = try resolvedNoteCategoryIDs(db: db, requested: categoryIDs)

                    try SessionNote.insert {
                        ($0.id, $0.sessionID, $0.text, $0.priority, $0.createdAt, $0.updatedAt)
                    } values: {
                        (noteID, sessionID, trimmed, priority.rawValue, now, now)
                    }
                    .execute(db)

                    try replaceNoteCategories(db: db, noteID: noteID, categoryIDs: resolvedCategoryIDs)
                    return try buildNoteRecord(db: db, noteID: noteID)
                }
            },
            updateNote: { noteID, text, priority, categoryIDs, now in
                @Dependency(\.defaultDatabase) var database

                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                return try await database.write { db in
                    if try SessionNote.find(noteID).fetchOne(db) == nil {
                        return nil
                    }

                    let resolvedCategoryIDs = try resolvedNoteCategoryIDs(db: db, requested: categoryIDs)

                    try SessionNote.find(noteID).update {
                        $0.text = trimmed
                        $0.priority = priority.rawValue
                        $0.updatedAt = now
                    }
                    .execute(db)

                    try replaceNoteCategories(db: db, noteID: noteID, categoryIDs: resolvedCategoryIDs)
                    return try buildNoteRecord(db: db, noteID: noteID)
                }
            },
            deleteNote: { noteID in
                @Dependency(\.defaultDatabase) var database

                try await database.write { db in
                    try SessionNote.find(noteID).delete().execute(db)
                }
            },
            exportSessionsMarkdown: { sessionIDs, directoryURL in
                @Dependency(\.defaultDatabase) var database

                if !FileManager.default.fileExists(atPath: directoryURL.path) {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                }

                return try await database.read { db in
                    var urls: [URL] = []
                    for sessionID in sessionIDs {
                        guard let session = try buildSessionRecord(db: db, sessionID: sessionID) else { continue }
                        let fileURL = directoryURL.appendingPathComponent(
                            FocusDefaults.markdownFileName(for: session),
                            isDirectory: false
                        )
                        try renderMarkdown(for: session).write(to: fileURL, atomically: true, encoding: .utf8)
                        urls.append(fileURL)
                    }
                    return urls
                }
            }
        )
    }

    static var testValue: FocusRepository {
        FocusRepository(
            startSession: { _ in
                FocusSessionRecord(
                    id: UUID(),
                    name: "Session",
                    startedAt: Date(),
                    endedAt: nil,
                    endedReason: nil,
                    notes: []
                )
            },
            loadActiveSession: { nil },
            endSession: { _, _, _, _ in nil },
            endSessionSync: { _, _, _, _ in },
            listSessions: { [] },
            renameSession: { _, _ in },
            deleteSession: { _ in },
            listCategories: { [] },
            addCategory: { _, _ in nil },
            renameCategory: { _, _, _ in },
            deleteCategory: { _ in },
            createNote: { _, _, _, _, _ in nil },
            updateNote: { _, _, _, _, _ in nil },
            deleteNote: { _ in },
            exportSessionsMarkdown: { _, _ in [] }
        )
    }
}

extension DependencyValues {
    var focusRepository: FocusRepository {
        get { self[FocusRepository.self] }
        set { self[FocusRepository.self] = newValue }
    }
}

enum FocusRepositoryError: Error {
    case notFound
}

private func buildSessionRecord(db: Database, sessionID: UUID) throws -> FocusSessionRecord? {
    guard let session = try FocusSession.find(sessionID).fetchOne(db) else {
        return nil
    }

    let notes = try SessionNote
        .where { $0.sessionID.eq(sessionID) }
        .order { $0.createdAt.asc() }
        .fetchAll(db)

    let noteRecords = try notes.map { note in
        guard let built = try buildNoteRecord(db: db, noteID: note.id) else {
            throw FocusRepositoryError.notFound
        }
        return built
    }

    return FocusSessionRecord(
        id: session.id,
        name: session.name,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        endedReason: session.endedReason.flatMap(SessionEndReason.init(rawValue:)),
        notes: noteRecords
    )
}

private func buildNoteRecord(db: Database, noteID: UUID) throws -> FocusNoteRecord? {
    guard let note = try SessionNote.find(noteID).fetchOne(db) else {
        return nil
    }
    let categories = try loadNoteCategories(db: db, noteID: noteID)

    return FocusNoteRecord(
        id: note.id,
        sessionID: note.sessionID,
        categories: categories,
        text: note.text,
        priority: NotePriority(rawValue: note.priority) ?? .none,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt
    )
}

private func normalizedSessionName(_ input: String?, fallbackDate: Date) -> String {
    let trimmed = (input ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return FocusDefaults.defaultSessionName(startedAt: fallbackDate)
    }
    return trimmed
}

private func resolvedNoteCategoryIDs(db: Database, requested: [UUID]) throws -> [UUID] {
    var seen = Set<UUID>()
    var values: [UUID] = []

    for id in requested {
        guard !seen.contains(id) else { continue }
        guard try SessionCategory.find(id).fetchOne(db) != nil else { continue }
        seen.insert(id)
        values.append(id)
    }

    return values
}

private func replaceNoteCategories(db: Database, noteID: UUID, categoryIDs: [UUID]) throws {
    try SessionNoteCategory.where { $0.noteID.eq(noteID) }.delete().execute(db)

    try SessionNoteCategory.insert {
        ($0.id, $0.noteID, $0.categoryID)
    } values: {
        for categoryID in categoryIDs {
            (UUID(), noteID, categoryID)
        }
    }
    .execute(db)
}

private func loadNoteCategories(
    db: Database,
    noteID: UUID
) throws -> [NoteCategoryRecord] {
    let linkedCategoryIDs = try SessionNoteCategory
        .where { $0.noteID.eq(noteID) }
        .order(by: \.categoryID)
        .fetchAll(db)
        .map(\.categoryID)

    var categories: [NoteCategoryRecord] = []
    for categoryID in linkedCategoryIDs {
        if let category = try SessionCategory.find(categoryID).fetchOne(db) {
            categories.append(
                NoteCategoryRecord(
                    id: category.id,
                    name: category.name,
                    colorHex: FocusDefaults.normalizedCategoryColorHex(category.colorHex)
                )
            )
        }
    }

    return categories
}

private func renderMarkdown(for session: FocusSessionRecord) -> String {
    var lines: [String] = []
    lines.append("# Session: \(session.name)")
    lines.append("Started: \(formatDate(session.startedAt))")
    if let endedAt = session.endedAt {
        lines.append("Ended: \(formatDate(endedAt))")
    }
    if let reason = session.endedReason {
        lines.append("Ended Reason: \(reason.rawValue)")
    }
    lines.append("")
    lines.append("## Notes")
    lines.append("")

    for note in session.notes.sorted(by: { $0.createdAt < $1.createdAt }) {
        lines.append("### \(formatDate(note.createdAt)) • \(note.priority.title)")
        let categoryLine = note.categories.isEmpty
            ? "None"
            : note.categories.map(\.name).joined(separator: ", ")
        lines.append("Categories: \(categoryLine)")
        lines.append(note.text)
        lines.append("")
    }

    return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
}

private func formatDate(_ date: Date) -> String {
    focusMarkdownFormatter.string(from: date)
}

private let focusMarkdownFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
}()
