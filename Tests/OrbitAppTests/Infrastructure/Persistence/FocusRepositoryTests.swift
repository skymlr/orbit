import Dependencies
import Foundation
import SQLiteData
import StructuredQueries
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct FocusRepositoryTests {
    @Test
    func createAndUpdateTaskPersistsCategories() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "B4CA36AD-BB5A-4A88-9874-3FA6F26D7E3F")!

        try seedSession(database: database, sessionID: sessionID)

        let created = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createTask(
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
            try await repository.updateTask(
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
    func setTaskCompletionTogglesCompletion() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "67CF4B5F-9A7C-4887-9193-189AE367503E")!

        try seedSession(database: database, sessionID: sessionID)

        let created = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createTask(
                sessionID,
                "Finish migration",
                .none,
                [],
                Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        let completed = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.setTaskCompletion(
                created!.id,
                true,
                Date(timeIntervalSince1970: 1_700_000_050)
            )
        }

        #expect(completed?.completedAt != nil)

        let reopened = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.setTaskCompletion(
                created!.id,
                false,
                Date(timeIntervalSince1970: 1_700_000_100)
            )
        }

        #expect(reopened?.completedAt == nil)
    }

    @Test
    func startSessionCarriesIncompleteTasksFromMostRecentEndedSession() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue

        let endedSessionID = UUID(uuidString: "3F8F66F7-8D29-4D2F-B779-E14945B2AAB2")!
        try seedSession(
            database: database,
            sessionID: endedSessionID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_300)
        )

        let sourceTask = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createTask(
                endedSessionID,
                "Carry this",
                .high,
                [projectACategoryID],
                Date(timeIntervalSince1970: 1_700_000_100)
            )
        }

        let started = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.startSession(Date(timeIntervalSince1970: 1_700_000_400))
        }

        #expect(started.tasks.count == 1)
        #expect(started.tasks[0].markdown == "Carry this")
        #expect(started.tasks[0].carriedFromTaskID == sourceTask?.id)
        #expect(started.tasks[0].carriedFromSessionName == "Repository Test Session")
        #expect(started.tasks[0].categories.map(\.id) == [projectACategoryID])
    }

    @Test
    func startSessionDoesNotCarryCompletedTasks() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue

        let endedSessionID = UUID(uuidString: "62ACF5D4-C97B-4D12-B9A8-E1C4FEE39D5D")!
        try seedSession(
            database: database,
            sessionID: endedSessionID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_300)
        )

        let created = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createTask(
                endedSessionID,
                "Do not carry",
                .none,
                [],
                Date(timeIntervalSince1970: 1_700_000_100)
            )
        }

        _ = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.setTaskCompletion(
                created!.id,
                true,
                Date(timeIntervalSince1970: 1_700_000_150)
            )
        }

        let started = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.startSession(Date(timeIntervalSince1970: 1_700_000_400))
        }

        #expect(started.tasks.isEmpty)
    }

    @Test
    func endSessionRoundTripsTimeWindowReason() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "3F749C97-30AB-4A45-97B2-FEA23C6AE03D")!
        let endedAt = Date(timeIntervalSince1970: 1_700_000_600)

        try seedSession(
            database: database,
            sessionID: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let ended = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.endSession(
                sessionID,
                nil,
                .timeWindow,
                endedAt
            )
        }

        #expect(ended?.endedReason == .timeWindow)

        let sessions = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.listSessions()
        }
        #expect(sessions.first?.endedReason == .timeWindow)
    }

    @Test
    func deleteCategoryUnassignsTaskCategories() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "7A1A66F7-8D29-4D2F-B779-E14945B2AAB2")!

        try seedSession(database: database, sessionID: sessionID)

        _ = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createTask(
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
        #expect(active?.tasks.count == 1)
        #expect(active?.tasks.first?.categories.isEmpty == true)
    }

    @Test
    func reconcileSyncInvariantsMergesDuplicateCategoriesAndDeduplicatesTaskLinks() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue

        let sessionID = UUID(uuidString: "7A1A66F7-8D29-4D2F-B779-E14945B2AAB3")!
        let taskID = UUID(uuidString: "82ACF5D4-C97B-4D12-B9A8-E1C4FEE39D5E")!
        let keptCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let duplicateCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!

        try seedSession(database: database, sessionID: sessionID)
        try await database.write { db in
            try prepareDatabaseForCloudKitSync(db: db)

            try #sql(
                """
                INSERT INTO "sessionCategories" ("id", "name", "normalizedName", "colorHex")
                VALUES
                  (\(bind: keptCategoryID.uuidString.lowercased()), 'Shared', 'shared', '#58B5FF'),
                  (\(bind: duplicateCategoryID.uuidString.lowercased()), 'shared', 'shared', '#7ED957')
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionTasks" ("id", "sessionID", "markdown", "priority", "completedAt", "carriedFromTaskID", "createdAt", "updatedAt")
                VALUES (
                  \(bind: taskID.uuidString.lowercased()),
                  \(bind: sessionID.uuidString.lowercased()),
                  'Consolidate sync categories',
                  'high',
                  NULL,
                  NULL,
                  \(bind: Date(timeIntervalSince1970: 1_700_000_000)),
                  \(bind: Date(timeIntervalSince1970: 1_700_000_050))
                )
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionTaskCategories" ("id", "taskID", "categoryID")
                VALUES
                  ('00000000-0000-0000-0000-000000000001', \(bind: taskID.uuidString.lowercased()), \(bind: keptCategoryID.uuidString.lowercased())),
                  ('00000000-0000-0000-0000-000000000002', \(bind: taskID.uuidString.lowercased()), \(bind: duplicateCategoryID.uuidString.lowercased())),
                  ('00000000-0000-0000-0000-000000000003', \(bind: taskID.uuidString.lowercased()), \(bind: duplicateCategoryID.uuidString.lowercased()))
                """
            )
            .execute(db)
        }

        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await repository.reconcileSyncInvariants()
        }

        try await database.read { db in
            let sharedCategories = try SessionCategory
                .where { $0.normalizedName.eq("shared") }
                .order(by: \.id)
                .fetchAll(db)

            let links = try SessionTaskCategory
                .where { $0.taskID.eq(taskID) }
                .fetchAll(db)

            #expect(sharedCategories.map(\.id) == [keptCategoryID])
            #expect(sharedCategories[0].name == "Shared")
            #expect(links.count == 1)
            #expect(links[0].categoryID == keptCategoryID)
        }
    }

    @Test
    func exportMarkdownShowsTaskStatusAndSections() async throws {
        let database = try makeTestDatabase()
        let repository = FocusRepository.liveValue
        let sessionID = UUID(uuidString: "82ACF5D4-C97B-4D12-B9A8-E1C4FEE39D5D")!

        try seedSession(database: database, sessionID: sessionID)

        let created = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.createTask(
                sessionID,
                "Draft release notes",
                .none,
                [],
                Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        _ = try await withDependencies {
            $0.defaultDatabase = database
            $0.uuid = .incrementing
        } operation: {
            try await repository.setTaskCompletion(
                created!.id,
                true,
                Date(timeIntervalSince1970: 1_700_000_100)
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

        #expect(markdown.contains("## Tasks"))
        #expect(markdown.contains("Status: Completed at"))
        #expect(markdown.contains("Categories: None"))
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
              "startedAt" TEXT NOT NULL,
              "endedAt" TEXT,
              "endedReason" TEXT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "sessionTasks" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "sessionID" TEXT NOT NULL REFERENCES "focusSessions"("id") ON DELETE CASCADE,
              "markdown" TEXT NOT NULL,
              "priority" TEXT NOT NULL,
              "completedAt" TEXT,
              "carriedFromTaskID" TEXT REFERENCES "sessionTasks"("id") ON DELETE SET NULL,
              "createdAt" TEXT NOT NULL,
              "updatedAt" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "sessionTaskCategories" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "taskID" TEXT NOT NULL REFERENCES "sessionTasks"("id") ON DELETE CASCADE,
              "categoryID" TEXT NOT NULL REFERENCES "sessionCategories"("id") ON DELETE RESTRICT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE UNIQUE INDEX "index_sessionTaskCategories_on_taskID_categoryID"
            ON "sessionTaskCategories"("taskID", "categoryID")
            """
        )
        .execute(db)

        try SessionCategory.insert {
            ($0.id, $0.name, $0.normalizedName, $0.colorHex)
        } values: {
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
    startedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
    endedAt: Date? = nil
) throws {
    try database.write { db in
        try FocusSession.insert {
            ($0.id, $0.name, $0.startedAt, $0.endedAt, $0.endedReason)
        } values: {
            (
                sessionID,
                "Repository Test Session",
                startedAt,
                endedAt,
                endedAt == nil ? nil : SessionEndReason.manual.rawValue
            )
        }
        .execute(db)
    }
}

private let projectACategoryID = UUID(uuidString: "3261E8B5-4302-4D32-9FDF-F5D4AB4AF4D9")!
private let projectBCategoryID = UUID(uuidString: "A4E2AC92-241D-40A1-AB2B-33804D08EE18")!
