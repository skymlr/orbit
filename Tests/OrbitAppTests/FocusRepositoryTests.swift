import Dependencies
import Foundation
import SQLiteData
import StructuredQueries
import Testing
@testable import OrbitApp

struct FocusRepositoryTests {
    @Test
    func createAndUpdateNotePersistsCategories() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "B4CA36AD-BB5A-4A88-9874-3FA6F26D7E3F")!

        try seedSession(database: database, sessionID: sessionID, sessionCategoryID: FocusDefaults.uncategorizedCategoryID)

        let created = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createNote(
                sessionID,
                "Plan migration",
                .medium,
                [projectACategoryID, projectBCategoryID],
                Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        #expect(created != nil)
        #expect(Set(created?.categories.map(\.id) ?? []) == Set([projectACategoryID, projectBCategoryID]))

        let updated = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.updateNote(
                created!.id,
                "Plan migration v2",
                .high,
                [projectBCategoryID],
                Date(timeIntervalSince1970: 1_700_000_100)
            )
        }

        #expect(updated?.categories.map(\.id) == [projectBCategoryID])
    }

    @Test
    func deleteCategoryRemapsSessionAndNoteCategoriesToUncategorized() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "3F8F66F7-8D29-4D2F-B779-E14945B2AAB2")!

        try seedSession(database: database, sessionID: sessionID, sessionCategoryID: projectACategoryID)

        _ = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createNote(
                sessionID,
                "Ship feature",
                .low,
                [projectACategoryID],
                Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.deleteCategory(projectACategoryID)
        }

        let active = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.loadActiveSession()
        }

        #expect(active != nil)
        #expect(active?.notes.count == 1)
        #expect(active?.notes.first?.categories.map(\.id) == [FocusDefaults.uncategorizedCategoryID])
        #expect(active?.notes.first?.categories.first?.name == FocusDefaults.uncategorizedCategoryName)
    }

    @Test
    func exportMarkdownIncludesNoteCategories() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "62ACF5D4-C97B-4D12-B9A8-E1C4FEE39D5D")!

        try seedSession(database: database, sessionID: sessionID, sessionCategoryID: FocusDefaults.uncategorizedCategoryID)

        _ = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createNote(
                sessionID,
                "Draft release notes",
                .none,
                [projectACategoryID, projectBCategoryID],
                Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        let exportDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("orbit-export-\(UUID().uuidString.lowercased())", isDirectory: true)

        let urls = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.exportSessionsMarkdown([sessionID], exportDirectory)
        }

        #expect(urls.count == 1)
        let markdown = try String(contentsOf: urls[0], encoding: .utf8)

        #expect(markdown.contains("Categories:"))
        #expect(markdown.contains("project-a"))
        #expect(markdown.contains("project-b"))
        #expect(!markdown.contains("Tags:"))
    }
}

private func makeTestDatabase() throws -> any DatabaseWriter {
    let databasePath = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("orbit-tests-\(UUID().uuidString.lowercased()).sqlite", isDirectory: false)
        .path
    let database = try SQLiteData.defaultDatabase(path: databasePath)

    try database.write { db in
        try #sql(
            """
            CREATE TABLE "sessionCategories" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "name" TEXT NOT NULL,
              "normalizedName" TEXT NOT NULL,
              "colorHex" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE UNIQUE INDEX "index_sessionCategories_on_normalizedName"
            ON "sessionCategories"("normalizedName")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "focusSessions" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "name" TEXT NOT NULL,
              "categoryID" TEXT NOT NULL REFERENCES "sessionCategories"("id") ON DELETE RESTRICT,
              "startedAt" TEXT NOT NULL,
              "endedAt" TEXT,
              "endedReason" TEXT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "sessionNotes" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "sessionID" TEXT NOT NULL REFERENCES "focusSessions"("id") ON DELETE CASCADE,
              "categoryID" TEXT NOT NULL REFERENCES "sessionCategories"("id") ON DELETE RESTRICT,
              "text" TEXT NOT NULL,
              "priority" TEXT NOT NULL,
              "createdAt" TEXT NOT NULL,
              "updatedAt" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "sessionNoteCategories" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "noteID" TEXT NOT NULL REFERENCES "sessionNotes"("id") ON DELETE CASCADE,
              "categoryID" TEXT NOT NULL REFERENCES "sessionCategories"("id") ON DELETE RESTRICT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE UNIQUE INDEX "index_sessionNoteCategories_on_noteID_categoryID"
            ON "sessionNoteCategories"("noteID", "categoryID")
            """
        )
        .execute(db)

        try SessionCategory.insert {
            ($0.id, $0.name, $0.normalizedName, $0.colorHex)
        } values: {
            (FocusDefaults.uncategorizedCategoryID, FocusDefaults.uncategorizedCategoryName, FocusDefaults.uncategorizedCategoryName, FocusDefaults.uncategorizedCategoryColorHex)
            (projectACategoryID, "project-a", "project-a", "#58B5FF")
            (projectBCategoryID, "project-b", "project-b", "#7ED957")
        }
        .execute(db)
    }

    return database
}

private func seedSession(
    database: any DatabaseWriter,
    sessionID: UUID,
    sessionCategoryID: UUID
) throws {
    try database.write { db in
        try FocusSession.insert {
            ($0.id, $0.name, $0.categoryID, $0.startedAt, $0.endedAt, $0.endedReason)
        } values: {
            (
                sessionID,
                "Repository Test Session",
                sessionCategoryID,
                Date(timeIntervalSince1970: 1_700_000_000),
                nil,
                nil
            )
        }
        .execute(db)
    }
}

private let projectACategoryID = UUID(uuidString: "3261E8B5-4302-4D32-9FDF-F5D4AB4AF4D9")!
private let projectBCategoryID = UUID(uuidString: "A4E2AC92-241D-40A1-AB2B-33804D08EE18")!
