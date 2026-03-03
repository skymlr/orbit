import Foundation
import SQLiteData
import StructuredQueries
import Testing
@testable import OrbitApp

struct SchemaMigrationTests {
    @Test
    func removeUncategorizedMigrationDropsLegacyColumnsAndLinks() throws {
        let databasePath = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("orbit-migration-tests-\(UUID().uuidString.lowercased()).sqlite", isDirectory: false)
            .path
        let database = try SQLiteData.defaultDatabase(path: databasePath)

        let uncategorizedID = UUID(uuidString: "C8B3B4CC-2928-4A84-9C3B-EB253E9D0001")!
        let projectID = UUID(uuidString: "3261E8B5-4302-4D32-9FDF-F5D4AB4AF4D9")!
        let sessionID = UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!
        let uncategorizedNoteID = UUID(uuidString: "A6E2C2D2-53AF-4D10-ACE2-761B700A1DB1")!
        let categorizedNoteID = UUID(uuidString: "DFBA97DE-5139-49DB-9D03-6F62A2A6A955")!

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
                INSERT INTO "sessionCategories" ("id", "name", "normalizedName", "colorHex")
                VALUES
                  (\(bind: uncategorizedID.uuidString.lowercased()), 'uncategorized', 'uncategorized', '#00B5FF'),
                  (\(bind: projectID.uuidString.lowercased()), 'project-a', 'project-a', '#58B5FF')
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "focusSessions" ("id", "name", "categoryID", "startedAt", "endedAt", "endedReason")
                VALUES (
                  \(bind: sessionID.uuidString.lowercased()),
                  'Migration Session',
                  \(bind: uncategorizedID.uuidString.lowercased()),
                  '2026-03-03T15:00:00Z',
                  NULL,
                  NULL
                )
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionNotes" ("id", "sessionID", "categoryID", "text", "priority", "createdAt", "updatedAt")
                VALUES
                  (
                    \(bind: uncategorizedNoteID.uuidString.lowercased()),
                    \(bind: sessionID.uuidString.lowercased()),
                    \(bind: uncategorizedID.uuidString.lowercased()),
                    'Uncategorized note',
                    'none',
                    '2026-03-03T15:01:00Z',
                    '2026-03-03T15:01:00Z'
                  ),
                  (
                    \(bind: categorizedNoteID.uuidString.lowercased()),
                    \(bind: sessionID.uuidString.lowercased()),
                    \(bind: projectID.uuidString.lowercased()),
                    'Categorized note',
                    'low',
                    '2026-03-03T15:02:00Z',
                    '2026-03-03T15:02:00Z'
                  )
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionNoteCategories" ("id", "noteID", "categoryID")
                VALUES
                  (
                    '00000000-0000-0000-0000-000000000001',
                    \(bind: uncategorizedNoteID.uuidString.lowercased()),
                    \(bind: uncategorizedID.uuidString.lowercased())
                  ),
                  (
                    '00000000-0000-0000-0000-000000000002',
                    \(bind: categorizedNoteID.uuidString.lowercased()),
                    \(bind: projectID.uuidString.lowercased())
                  )
                """
            )
            .execute(db)
        }

        var migrator = DatabaseMigrator()
        migrator.registerMigration("Remove uncategorized and legacy category columns") { db in
            try removeUncategorizedAndLegacyCategoryColumns(db: db)
        }
        try migrator.migrate(database)

        try database.read { db in
            let sessionColumns = try db.columns(in: "focusSessions").map(\.name)
            let noteColumns = try db.columns(in: "sessionNotes").map(\.name)

            #expect(!sessionColumns.contains("categoryID"))
            #expect(!noteColumns.contains("categoryID"))

            let uncategorizedCategoryCount = try SessionCategory
                .where { $0.normalizedName.eq("uncategorized") }
                .fetchCount(db)
            #expect(uncategorizedCategoryCount == 0)

            let uncategorizedNoteCategoryCount = try SessionNoteCategory
                .where { $0.noteID.eq(uncategorizedNoteID) }
                .fetchCount(db)
            #expect(uncategorizedNoteCategoryCount == 0)

            let categorizedNoteCategoryCount = try SessionNoteCategory
                .where { $0.noteID.eq(categorizedNoteID) }
                .fetchCount(db)
            #expect(categorizedNoteCategoryCount == 1)
        }
    }
}
