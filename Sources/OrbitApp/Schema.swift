import Dependencies
import Foundation
import SQLiteData
import StructuredQueries

extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        let database = try SQLiteData.defaultDatabase(path: orbitDatabasePath())
        var migrator = DatabaseMigrator()
#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif

        migrator.registerMigration("Create Orbit focus tables") { db in
            try #sql(
                """
                CREATE TABLE "sessionCategories" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL,
                  "normalizedName" TEXT NOT NULL
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
                CREATE INDEX "index_focusSessions_on_startedAt"
                ON "focusSessions"("startedAt" DESC)
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "sessionNotes" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "sessionID" TEXT NOT NULL REFERENCES "focusSessions"("id") ON DELETE CASCADE,
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
                CREATE INDEX "index_sessionNotes_on_sessionID_createdAt"
                ON "sessionNotes"("sessionID", "createdAt" DESC)
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "sessionNoteTags" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "noteID" TEXT NOT NULL REFERENCES "sessionNotes"("id") ON DELETE CASCADE,
                  "name" TEXT NOT NULL,
                  "normalizedName" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE UNIQUE INDEX "index_sessionNoteTags_on_noteID_normalizedName"
                ON "sessionNoteTags"("noteID", "normalizedName")
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionCategories" ("id", "name", "normalizedName")
                VALUES ('c8b3b4cc-2928-4a84-9c3b-eb253e9d0001', 'focus', 'focus')
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Normalize focus category identifier casing") { db in
            try #sql(
                """
                INSERT INTO "sessionCategories" ("id", "name", "normalizedName")
                VALUES ('c8b3b4cc-2928-4a84-9c3b-eb253e9d0001', 'focus', 'focus')
                ON CONFLICT("normalizedName") DO UPDATE
                SET
                  "id" = 'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001',
                  "name" = 'focus',
                  "normalizedName" = 'focus'
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Add colors to session categories") { db in
            try #sql(
                """
                ALTER TABLE "sessionCategories"
                ADD COLUMN "colorHex" TEXT NOT NULL DEFAULT '#58B5FF'
                """
            )
            .execute(db)

            try #sql(
                """
                UPDATE "sessionCategories"
                SET "colorHex" = '#00B5FF'
                WHERE "normalizedName" = 'focus'
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Move category ownership to notes") { db in
            try #sql(
                """
                UPDATE "focusSessions"
                SET "categoryID" = 'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001'
                WHERE "categoryID" IN (
                  SELECT "id"
                  FROM "sessionCategories"
                  WHERE "normalizedName" = 'uncategorized'
                    AND "id" <> 'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001'
                )
                """
            )
            .execute(db)

            try #sql(
                """
                DELETE FROM "sessionCategories"
                WHERE "normalizedName" = 'uncategorized'
                  AND "id" <> 'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001'
                """
            )
            .execute(db)

            try #sql(
                """
                INSERT INTO "sessionCategories" ("id", "name", "normalizedName", "colorHex")
                VALUES (
                  'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001',
                  'uncategorized',
                  'uncategorized',
                  '#00B5FF'
                )
                ON CONFLICT("id") DO UPDATE
                SET
                  "name" = 'uncategorized',
                  "normalizedName" = 'uncategorized',
                  "colorHex" = '#00B5FF'
                """
            )
            .execute(db)

            try #sql(
                """
                ALTER TABLE "sessionNotes"
                ADD COLUMN "categoryID" TEXT NOT NULL REFERENCES "sessionCategories"("id") ON DELETE RESTRICT
                DEFAULT 'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001'
                """
            )
            .execute(db)

            try #sql(
                """
                UPDATE "sessionNotes"
                SET "categoryID" = COALESCE(
                  (
                    SELECT "focusSessions"."categoryID"
                    FROM "focusSessions"
                    WHERE "focusSessions"."id" = "sessionNotes"."sessionID"
                  ),
                  'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001'
                )
                """
            )
            .execute(db)

            try #sql(
                """
                UPDATE "sessionNotes"
                SET "categoryID" = 'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001'
                WHERE "categoryID" IS NULL
                  OR "categoryID" NOT IN (
                    SELECT "id" FROM "sessionCategories"
                  )
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE INDEX "index_sessionNotes_on_sessionID_categoryID_createdAt"
                ON "sessionNotes"("sessionID", "categoryID", "createdAt" DESC)
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Support multiple categories per note") { db in
            try #sql(
                """
                INSERT OR IGNORE INTO "sessionCategories" ("id", "name", "normalizedName", "colorHex")
                VALUES ('c8b3b4cc-2928-4a84-9c3b-eb253e9d0001', 'uncategorized', 'uncategorized', '#00B5FF')
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

            try #sql(
                """
                CREATE INDEX "index_sessionNoteCategories_on_categoryID_noteID"
                ON "sessionNoteCategories"("categoryID", "noteID")
                """
            )
            .execute(db)

            let notes = try SessionNote.fetchAll(db)
            for note in notes {
                let resolvedCategoryID: UUID
                if try SessionCategory.find(note.categoryID).fetchOne(db) != nil {
                    resolvedCategoryID = note.categoryID
                } else {
                    resolvedCategoryID = FocusDefaults.uncategorizedCategoryID
                }

                try SessionNoteCategory.insert {
                    ($0.id, $0.noteID, $0.categoryID)
                } values: {
                    (UUID(), note.id, resolvedCategoryID)
                }
                .execute(db)
            }
        }

        migrator.registerMigration("Remove note tags table") { db in
            try #sql(
                """
                DROP TABLE IF EXISTS "sessionNoteTags"
                """
            )
            .execute(db)
        }

        try migrator.migrate(database)
        defaultDatabase = database
    }
}

private func orbitDatabasePath() throws -> String {
    let fileManager = FileManager.default
    guard let appSupportDirectory = fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first else {
        throw CocoaError(.fileNoSuchFile)
    }

    let directory = appSupportDirectory
        .appendingPathComponent("Orbit", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    return directory
        .appendingPathComponent("focus.sqlite", isDirectory: false)
        .path
}
