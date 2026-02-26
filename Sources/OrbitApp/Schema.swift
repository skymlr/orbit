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
