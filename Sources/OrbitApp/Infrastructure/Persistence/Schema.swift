import Dependencies
import Foundation
import SQLiteData
import StructuredQueries

extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        var configuration = Configuration()
        if orbitSupportsCloudSync {
            configuration.prepareDatabase { db in
                try db.attachMetadatabase(
                    containerIdentifier: orbitCloudSyncContainerIdentifier
                )
            }
        }

        let database = try SQLiteData.defaultDatabase(
            path: orbitDatabasePath(),
            configuration: configuration
        )
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

            try #sql(
                """
                INSERT INTO "sessionNoteCategories" ("id", "noteID", "categoryID")
                SELECT
                  lower(
                    hex(randomblob(4)) || '-' ||
                    hex(randomblob(2)) || '-' ||
                    hex(randomblob(2)) || '-' ||
                    hex(randomblob(2)) || '-' ||
                    hex(randomblob(6))
                  ),
                  "sessionNotes"."id",
                  CASE
                    WHEN "sessionNotes"."categoryID" IN (SELECT "id" FROM "sessionCategories")
                      THEN "sessionNotes"."categoryID"
                    ELSE 'c8b3b4cc-2928-4a84-9c3b-eb253e9d0001'
                  END
                FROM "sessionNotes"
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Remove note tags table") { db in
            try #sql(
                """
                DROP TABLE IF EXISTS "sessionNoteTags"
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Remove uncategorized and legacy category columns") { db in
            try removeUncategorizedAndLegacyCategoryColumns(db: db)
        }

        migrator.registerMigration("Repair orphan legacy notes before task migration") { db in
            try repairOrphanLegacyNotes(db: db)
        }

        migrator.registerMigration("Prune sessions before 2026-03-02 local") { db in
            try pruneSessionsBeforeTaskRefactorCutoff(db: db)
        }

        migrator.registerMigration("Convert notes to tasks") { db in
            try convertNotesToTasks(db: db)
        }

        migrator.registerMigration("Prepare database for CloudKit sync") { db in
            try prepareDatabaseForCloudKitSync(db: db)
        }

        try migrator.migrate(database)
        try database.write { db in
            try reconcileOrbitSyncInvariants(db: db)
        }
        defaultDatabase = database
        if orbitSupportsCloudSync {
            defaultSyncEngine = try SyncEngine(
                for: database,
                tables: FocusSession.self,
                privateTables: SessionCategory.self, SessionTask.self, SessionTaskCategory.self,
                containerIdentifier: orbitCloudSyncContainerIdentifier,
                startImmediately: false,
                delegate: orbitSyncEngineDelegate
            )
        }
    }
}

func removeUncategorizedAndLegacyCategoryColumns(db: Database) throws {
    try #sql(
        """
        DROP INDEX IF EXISTS "index_focusSessions_on_startedAt"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP INDEX IF EXISTS "index_sessionNotes_on_sessionID_createdAt"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP INDEX IF EXISTS "index_sessionNotes_on_sessionID_categoryID_createdAt"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP INDEX IF EXISTS "index_sessionNoteCategories_on_noteID_categoryID"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP INDEX IF EXISTS "index_sessionNoteCategories_on_categoryID_noteID"
        """
    )
    .execute(db)

    try #sql(
        """
        ALTER TABLE "focusSessions" RENAME TO "focusSessions_legacy"
        """
    )
    .execute(db)

    try #sql(
        """
        ALTER TABLE "sessionNotes" RENAME TO "sessionNotes_legacy"
        """
    )
    .execute(db)

    try #sql(
        """
        ALTER TABLE "sessionNoteCategories" RENAME TO "sessionNoteCategories_legacy"
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
        INSERT INTO "focusSessions" ("id", "name", "startedAt", "endedAt", "endedReason")
        SELECT "id", "name", "startedAt", "endedAt", "endedReason"
        FROM "focusSessions_legacy"
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
        INSERT INTO "sessionNotes" ("id", "sessionID", "text", "priority", "createdAt", "updatedAt")
        SELECT "id", "sessionID", "text", "priority", "createdAt", "updatedAt"
        FROM "sessionNotes_legacy"
        WHERE "sessionID" IN (SELECT "id" FROM "focusSessions")
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
        INSERT INTO "sessionNoteCategories" ("id", "noteID", "categoryID")
        SELECT
          lower(
            hex(randomblob(4)) || '-' ||
            hex(randomblob(2)) || '-' ||
            hex(randomblob(2)) || '-' ||
            hex(randomblob(2)) || '-' ||
            hex(randomblob(6))
          ),
          "dedup"."noteID",
          "dedup"."categoryID"
        FROM (
          SELECT DISTINCT
            "existing"."noteID" AS "noteID",
            "existing"."categoryID" AS "categoryID"
          FROM "sessionNoteCategories_legacy" AS "existing"
          INNER JOIN "sessionNotes" AS "note" ON "note"."id" = "existing"."noteID"
          INNER JOIN "sessionCategories" AS "category" ON "category"."id" = "existing"."categoryID"
          WHERE "category"."normalizedName" <> 'uncategorized'
        ) AS "dedup"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP TABLE "sessionNoteCategories_legacy"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP TABLE "sessionNotes_legacy"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP TABLE "focusSessions_legacy"
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
        CREATE INDEX "index_sessionNotes_on_sessionID_createdAt"
        ON "sessionNotes"("sessionID", "createdAt" DESC)
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

    try #sql(
        """
        DELETE FROM "sessionCategories"
        WHERE "normalizedName" = 'uncategorized'
        """
    )
    .execute(db)
}

func pruneSessionsBeforeTaskRefactorCutoff(db: Database) throws {
    try #sql(
        """
        DELETE FROM "sessionNoteCategories"
        WHERE "noteID" IN (
          SELECT "id"
          FROM "sessionNotes"
          WHERE "sessionID" IN (
            SELECT "id"
            FROM "focusSessions"
            WHERE "startedAt" < \(bind: taskRefactorCutoffDate)
          )
        )
        """
    )
    .execute(db)

    try #sql(
        """
        DELETE FROM "sessionNotes"
        WHERE "sessionID" IN (
          SELECT "id"
          FROM "focusSessions"
          WHERE "startedAt" < \(bind: taskRefactorCutoffDate)
        )
        """
    )
    .execute(db)

    try #sql(
        """
        DELETE FROM "focusSessions"
        WHERE "startedAt" < \(bind: taskRefactorCutoffDate)
        """
    )
    .execute(db)
}

func repairOrphanLegacyNotes(db: Database) throws {
    try #sql(
        """
        DELETE FROM "sessionNoteCategories"
        WHERE "noteID" NOT IN (SELECT "id" FROM "sessionNotes")
           OR "categoryID" NOT IN (SELECT "id" FROM "sessionCategories")
        """
    )
    .execute(db)

    try #sql(
        """
        DELETE FROM "sessionNotes"
        WHERE "sessionID" NOT IN (SELECT "id" FROM "focusSessions")
        """
    )
    .execute(db)
}

func convertNotesToTasks(db: Database) throws {
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
        INSERT INTO "sessionTasks" (
          "id",
          "sessionID",
          "markdown",
          "priority",
          "completedAt",
          "carriedFromTaskID",
          "createdAt",
          "updatedAt"
        )
        SELECT
          "sessionNotes"."id",
          "sessionNotes"."sessionID",
          "sessionNotes"."text",
          "sessionNotes"."priority",
          NULL,
          NULL,
          "sessionNotes"."createdAt",
          "sessionNotes"."updatedAt"
        FROM "sessionNotes"
        INNER JOIN "focusSessions" ON "focusSessions"."id" = "sessionNotes"."sessionID"
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
        INSERT INTO "sessionTaskCategories" ("id", "taskID", "categoryID")
        SELECT
          lower(
            hex(randomblob(4)) || '-' ||
            hex(randomblob(2)) || '-' ||
            hex(randomblob(2)) || '-' ||
            hex(randomblob(2)) || '-' ||
            hex(randomblob(6))
          ),
          "sessionNoteCategories"."noteID",
          "sessionNoteCategories"."categoryID"
        FROM "sessionNoteCategories"
        INNER JOIN "sessionTasks" ON "sessionTasks"."id" = "sessionNoteCategories"."noteID"
        """
    )
    .execute(db)

    try #sql(
        """
        CREATE INDEX "index_sessionTasks_on_sessionID_createdAt"
        ON "sessionTasks"("sessionID", "createdAt" DESC)
        """
    )
    .execute(db)

    try #sql(
        """
        CREATE INDEX "index_sessionTasks_on_sessionID_completedAt_createdAt"
        ON "sessionTasks"("sessionID", "completedAt", "createdAt" DESC)
        """
    )
    .execute(db)

    try #sql(
        """
        CREATE INDEX "index_sessionTasks_on_carriedFromTaskID"
        ON "sessionTasks"("carriedFromTaskID")
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

    try #sql(
        """
        CREATE INDEX "index_sessionTaskCategories_on_categoryID_taskID"
        ON "sessionTaskCategories"("categoryID", "taskID")
        """
    )
    .execute(db)

    try #sql(
        """
        DROP TABLE "sessionNoteCategories"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP TABLE "sessionNotes"
        """
    )
    .execute(db)
}

func prepareDatabaseForCloudKitSync(db: Database) throws {
    try #sql(
        """
        DROP INDEX IF EXISTS "index_sessionCategories_on_normalizedName"
        """
    )
    .execute(db)

    try #sql(
        """
        DROP INDEX IF EXISTS "index_sessionTaskCategories_on_taskID_categoryID"
        """
    )
    .execute(db)
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

private let taskRefactorCutoffDate: Date = {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: "2026-03-02T06:00:00Z")!
}()

private let orbitCloudSyncContainerIdentifier = "iCloud.com.smiller.orbit.data"
private let orbitSupportsCloudSync: Bool = {
#if LOCAL_UNSIGNED
    false
#else
    true
#endif
}()

@available(iOS 17, macOS 14, *)
private let orbitSyncEngineDelegate = OrbitSyncEngineDelegate()
