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

    var createTask: @Sendable (_ sessionID: UUID, _ markdown: String, _ priority: NotePriority, _ categoryIDs: [UUID], _ now: Date) async throws -> FocusTaskRecord?
    var updateTask: @Sendable (_ taskID: UUID, _ markdown: String, _ priority: NotePriority, _ categoryIDs: [UUID], _ now: Date) async throws -> FocusTaskRecord?
    var setTaskCompletion: @Sendable (_ taskID: UUID, _ isCompleted: Bool, _ now: Date) async throws -> FocusTaskRecord?
    var deleteTask: @Sendable (_ taskID: UUID) async throws -> Void

    var exportSessionsMarkdown: @Sendable (_ sessionIDs: [UUID], _ directoryURL: URL) async throws -> [URL]
}

extension FocusRepository: DependencyKey {
    static var liveValue: FocusRepository {
        FocusRepository(
            startSession: { now in
                @Dependency(\.defaultDatabase) var database
                @Dependency(\.uuid) var uuid

                return try await database.write { db in
                    let active = try FocusSession
                        .where({ $0.endedAt.is(nil) })
                        .order { $0.startedAt.desc() }
                        .fetchOne(db)

                    if let active, let record = try buildSessionRecord(db: db, sessionID: active.id) {
                        return record
                    }

                    let sessionID = uuid()
                    let name = FocusDefaults.defaultSessionName(startedAt: now)

                    try FocusSession.insert {
                        ($0.id, $0.name, $0.startedAt, $0.endedAt, $0.endedReason)
                    } values: {
                        (sessionID, name, now, nil, nil)
                    }
                    .execute(db)

                    if let previousEndedSession = try mostRecentlyEndedSession(db: db, excluding: sessionID) {
                        try copyIncompleteTasks(
                            db: db,
                            fromSessionID: previousEndedSession.id,
                            toSessionID: sessionID,
                            copiedAt: now,
                            uuid: { uuid() }
                        )
                    }

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

                return try await database.read { db in
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
                    let categoryCount = try SessionCategory.fetchCount(db)
                    guard categoryCount < FocusDefaults.maxCategoryCount else {
                        throw FocusRepositoryError.categoryLimitReached
                    }

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
                    try SessionTaskCategory.where { $0.categoryID.eq(id) }
                        .delete()
                        .execute(db)

                    try SessionCategory.find(id).delete().execute(db)
                }
            },
            createTask: { sessionID, markdown, priority, categoryIDs, now in
                @Dependency(\.defaultDatabase) var database
                @Dependency(\.uuid) var uuid

                let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let taskID = uuid()

                return try await database.write { db in
                    if try FocusSession.find(sessionID).fetchOne(db) == nil {
                        return nil
                    }

                    let resolvedCategoryIDs = try resolvedTaskCategoryIDs(db: db, requested: categoryIDs)

                    try SessionTask.insert {
                        ($0.id, $0.sessionID, $0.markdown, $0.priority, $0.completedAt, $0.carriedFromTaskID, $0.createdAt, $0.updatedAt)
                    } values: {
                        (taskID, sessionID, trimmed, priority.rawValue, nil, nil, now, now)
                    }
                    .execute(db)

                    try replaceTaskCategories(db: db, taskID: taskID, categoryIDs: resolvedCategoryIDs)
                    return try buildTaskRecord(db: db, taskID: taskID)
                }
            },
            updateTask: { taskID, markdown, priority, categoryIDs, now in
                @Dependency(\.defaultDatabase) var database

                let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                return try await database.write { db in
                    if try SessionTask.find(taskID).fetchOne(db) == nil {
                        return nil
                    }

                    let resolvedCategoryIDs = try resolvedTaskCategoryIDs(db: db, requested: categoryIDs)

                    try SessionTask.find(taskID).update {
                        $0.markdown = trimmed
                        $0.priority = priority.rawValue
                        $0.updatedAt = now
                    }
                    .execute(db)

                    try replaceTaskCategories(db: db, taskID: taskID, categoryIDs: resolvedCategoryIDs)
                    return try buildTaskRecord(db: db, taskID: taskID)
                }
            },
            setTaskCompletion: { taskID, isCompleted, now in
                @Dependency(\.defaultDatabase) var database

                return try await database.write { db in
                    if try SessionTask.find(taskID).fetchOne(db) == nil {
                        return nil
                    }

                    try SessionTask.find(taskID).update {
                        $0.completedAt = isCompleted ? #bind(now) : nil
                        $0.updatedAt = now
                    }
                    .execute(db)

                    return try buildTaskRecord(db: db, taskID: taskID)
                }
            },
            deleteTask: { taskID in
                @Dependency(\.defaultDatabase) var database

                try await database.write { db in
                    try SessionTask.find(taskID).delete().execute(db)
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
                    tasks: []
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
            createTask: { _, _, _, _, _ in nil },
            updateTask: { _, _, _, _, _ in nil },
            setTaskCompletion: { _, _, _ in nil },
            deleteTask: { _ in },
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
    case categoryLimitReached
}

private func buildSessionRecord(db: Database, sessionID: UUID) throws -> FocusSessionRecord? {
    guard let session = try FocusSession.find(sessionID).fetchOne(db) else {
        return nil
    }

    let tasks = try SessionTask
        .where { $0.sessionID.eq(sessionID) }
        .order { $0.createdAt.asc() }
        .fetchAll(db)

    let taskRecords = try tasks.map { task in
        guard let built = try buildTaskRecord(db: db, taskID: task.id) else {
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
        tasks: taskRecords
    )
}

private func buildTaskRecord(db: Database, taskID: UUID) throws -> FocusTaskRecord? {
    guard let task = try SessionTask.find(taskID).fetchOne(db) else {
        return nil
    }
    let categories = try loadTaskCategories(db: db, taskID: taskID)
    let carriedFromSessionName = try loadCarriedFromSessionName(db: db, carriedFromTaskID: task.carriedFromTaskID)

    return FocusTaskRecord(
        id: task.id,
        sessionID: task.sessionID,
        categories: categories,
        markdown: task.markdown,
        priority: NotePriority(rawValue: task.priority) ?? .none,
        completedAt: task.completedAt,
        carriedFromTaskID: task.carriedFromTaskID,
        carriedFromSessionName: carriedFromSessionName,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt
    )
}

private func normalizedSessionName(_ input: String?, fallbackDate: Date) -> String {
    let trimmed = (input ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return FocusDefaults.defaultSessionName(startedAt: fallbackDate)
    }
    return trimmed
}

private func resolvedTaskCategoryIDs(db: Database, requested: [UUID]) throws -> [UUID] {
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

private func replaceTaskCategories(db: Database, taskID: UUID, categoryIDs: [UUID]) throws {
    try SessionTaskCategory.where { $0.taskID.eq(taskID) }.delete().execute(db)

    try SessionTaskCategory.insert {
        ($0.id, $0.taskID, $0.categoryID)
    } values: {
        for categoryID in categoryIDs {
            (UUID(), taskID, categoryID)
        }
    }
    .execute(db)
}

private func loadTaskCategories(
    db: Database,
    taskID: UUID
) throws -> [NoteCategoryRecord] {
    let linkedCategoryIDs = try SessionTaskCategory
        .where { $0.taskID.eq(taskID) }
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

private func loadCarriedFromSessionName(
    db: Database,
    carriedFromTaskID: UUID?
) throws -> String? {
    guard let carriedFromTaskID else { return nil }
    guard let sourceTask = try SessionTask.find(carriedFromTaskID).fetchOne(db) else { return nil }
    guard let sourceSession = try FocusSession.find(sourceTask.sessionID).fetchOne(db) else { return nil }
    return sourceSession.name
}

private func mostRecentlyEndedSession(
    db: Database,
    excluding excludedSessionID: UUID
) throws -> FocusSession? {
    let sessions = try FocusSession
        .order { $0.startedAt.desc() }
        .fetchAll(db)

    return sessions
        .filter { $0.id != excludedSessionID && $0.endedAt != nil }
        .sorted {
            ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast)
        }
        .first
}

private func copyIncompleteTasks(
    db: Database,
    fromSessionID: UUID,
    toSessionID: UUID,
    copiedAt: Date,
    uuid: @escaping @Sendable () -> UUID
) throws {
    let sourceTasks = try SessionTask
        .where { $0.sessionID.eq(fromSessionID) }
        .order { $0.createdAt.asc() }
        .fetchAll(db)
        .filter { $0.completedAt == nil }

    for sourceTask in sourceTasks {
        let copiedTaskID = uuid()

        try SessionTask.insert {
            ($0.id, $0.sessionID, $0.markdown, $0.priority, $0.completedAt, $0.carriedFromTaskID, $0.createdAt, $0.updatedAt)
        } values: {
            (
                copiedTaskID,
                toSessionID,
                sourceTask.markdown,
                sourceTask.priority,
                nil,
                sourceTask.id,
                copiedAt,
                copiedAt
            )
        }
        .execute(db)

        let sourceCategoryIDs = try SessionTaskCategory
            .where { $0.taskID.eq(sourceTask.id) }
            .fetchAll(db)
            .map(\.categoryID)

        try SessionTaskCategory.insert {
            ($0.id, $0.taskID, $0.categoryID)
        } values: {
            for categoryID in sourceCategoryIDs {
                (uuid(), copiedTaskID, categoryID)
            }
        }
        .execute(db)
    }
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
    lines.append("## Tasks")
    lines.append("")

    for task in session.tasks.sorted(by: { $0.createdAt < $1.createdAt }) {
        lines.append("### \(formatDate(task.createdAt)) • \(task.priority.title)")
        if let completedAt = task.completedAt {
            lines.append("Status: Completed at \(formatDate(completedAt))")
        } else {
            lines.append("Status: Open")
        }
        if task.carriedFromTaskID != nil {
            let carriedFromSessionName = task.carriedFromSessionName ?? "Previous session"
            lines.append("Carried From Session: \(carriedFromSessionName)")
        }
        let categoryLine = task.categories.isEmpty
            ? "None"
            : task.categories.map(\.name).joined(separator: ", ")
        lines.append("Categories: \(categoryLine)")
        lines.append(task.markdown)
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
