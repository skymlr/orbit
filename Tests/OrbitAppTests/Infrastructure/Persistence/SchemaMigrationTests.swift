import Foundation
import SQLiteData
import StructuredQueries
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct SchemaMigrationTests {
    @Test
    func pruneAndConvertNotesToTasksMigrationWorks() throws {
        let databasePath = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("orbit-migration-tests-\(UUID().uuidString.lowercased()).sqlite", isDirectory: false)
            .path
        let database = try SQLiteData.defaultDatabase(path: databasePath)

        let projectID = UUID(uuidString: "3261E8B5-4302-4D32-9FDF-F5D4AB4AF4D9")!
        let oldSessionID = UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!
        let recentSessionID = UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D41")!
        let orphanSessionID = UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D99")!
        let oldNoteID = UUID(uuidString: "A6E2C2D2-53AF-4D10-ACE2-761B700A1DB1")!
        let recentNoteID = UUID(uuidString: "DFBA97DE-5139-49DB-9D03-6F62A2A6A955")!
        let orphanNoteID = UUID(uuidString: "AFBA97DE-5139-49DB-9D03-6F62A2A6A955")!
        let cutoff = ISO8601DateFormatter().date(from: "2026-03-02T06:00:00Z")!
        let oldSessionStartedAt = cutoff.addingTimeInterval(-60)
        let oldSessionEndedAt = cutoff.addingTimeInterval(-30)
        let recentSessionEndedAt = cutoff.addingTimeInterval(30 * 60)
        let oldNoteCreatedAt = cutoff.addingTimeInterval(-55)
        let recentNoteCreatedAt = cutoff.addingTimeInterval(60)

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
                CREATE TABLE "sessionNotes" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "sessionID" TEXT NOT NULL,
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
                  "noteID" TEXT NOT NULL,
                  "categoryID" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionCategories" ("id", "name", "normalizedName", "colorHex")
                VALUES (
                  \(bind: projectID.uuidString.lowercased()),
                  'project-a',
                  'project-a',
                  '#58B5FF'
                )
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "focusSessions" ("id", "name", "startedAt", "endedAt", "endedReason")
                VALUES (
                  \(bind: oldSessionID.uuidString.lowercased()),
                  'Old Session',
                  \(bind: oldSessionStartedAt),
                  \(bind: oldSessionEndedAt),
                  'manual'
                )
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "focusSessions" ("id", "name", "startedAt", "endedAt", "endedReason")
                VALUES (
                  \(bind: recentSessionID.uuidString.lowercased()),
                  'Recent Session',
                  \(bind: cutoff),
                  \(bind: recentSessionEndedAt),
                  'manual'
                )
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionNotes" ("id", "sessionID", "text", "priority", "createdAt", "updatedAt")
                VALUES
                  (
                    \(bind: oldNoteID.uuidString.lowercased()),
                    \(bind: oldSessionID.uuidString.lowercased()),
                    'Old note',
                    'none',
                    \(bind: oldNoteCreatedAt),
                    \(bind: oldNoteCreatedAt)
                  ),
                  (
                    \(bind: recentNoteID.uuidString.lowercased()),
                    \(bind: recentSessionID.uuidString.lowercased()),
                    'Recent note',
                    'high',
                    \(bind: recentNoteCreatedAt),
                    \(bind: recentNoteCreatedAt)
                  ),
                  (
                    \(bind: orphanNoteID.uuidString.lowercased()),
                    \(bind: orphanSessionID.uuidString.lowercased()),
                    'Orphan note',
                    'low',
                    \(bind: recentNoteCreatedAt),
                    \(bind: recentNoteCreatedAt)
                  )
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionNoteCategories" ("id", "noteID", "categoryID")
                VALUES
                  ('00000000-0000-0000-0000-000000000001', \(bind: oldNoteID.uuidString.lowercased()), \(bind: projectID.uuidString.lowercased())),
                  ('00000000-0000-0000-0000-000000000002', \(bind: recentNoteID.uuidString.lowercased()), \(bind: projectID.uuidString.lowercased())),
                  ('00000000-0000-0000-0000-000000000003', \(bind: orphanNoteID.uuidString.lowercased()), \(bind: projectID.uuidString.lowercased()))
                """
            )
            .execute(db)
        }

        var migrator = DatabaseMigrator()
        migrator.registerMigration("Repair orphan legacy notes before task migration") { db in
            try repairOrphanLegacyNotes(db: db)
        }
        migrator.registerMigration("Prune sessions before 2026-03-02 local") { db in
            try pruneSessionsBeforeTaskRefactorCutoff(db: db)
        }
        migrator.registerMigration("Convert notes to tasks") { db in
            try convertNotesToTasks(db: db)
        }
        try migrator.migrate(database)

        try database.read { db in
            let remainingSessionIDs = try FocusSession
                .order(by: \.startedAt)
                .fetchAll(db)
                .map(\.id)
            #expect(remainingSessionIDs == [recentSessionID])

            let migratedTasks = try SessionTask
                .order(by: \.createdAt)
                .fetchAll(db)
            #expect(migratedTasks.count == 1)
            #expect(migratedTasks[0].id == recentNoteID)
            #expect(migratedTasks[0].markdown == "Recent note")
            #expect(migratedTasks[0].completedAt == nil)
            #expect(migratedTasks[0].carriedFromTaskID == nil)

            let migratedLinks = try SessionTaskCategory.fetchAll(db)
            #expect(migratedLinks.count == 1)
            #expect(migratedLinks[0].taskID == recentNoteID)
            #expect(migratedLinks[0].categoryID == projectID)

            let taskColumns = try db.columns(in: "sessionTasks").map(\.name)
            #expect(taskColumns.contains("completedAt"))
            #expect(taskColumns.contains("carriedFromTaskID"))

            let legacyNotesColumns = try? db.columns(in: "sessionNotes")
            let legacyLinksColumns = try? db.columns(in: "sessionNoteCategories")
            #expect(legacyNotesColumns == nil)
            #expect(legacyLinksColumns == nil)
        }
    }
}
