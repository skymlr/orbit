import Foundation
import SQLiteData
import StructuredQueries

func reconcileOrbitSyncInvariants(db: Database) throws {
    try #sql(
        """
        UPDATE "sessionTaskCategories"
        SET "categoryID" = (
          SELECT "duplicates"."keptID"
          FROM (
            SELECT "normalizedName", MIN("id") AS "keptID"
            FROM "sessionCategories"
            GROUP BY "normalizedName"
            HAVING COUNT(*) > 1
          ) AS "duplicates"
          INNER JOIN "sessionCategories" AS "duplicateCategory"
            ON "duplicateCategory"."normalizedName" = "duplicates"."normalizedName"
          WHERE "duplicateCategory"."id" = "sessionTaskCategories"."categoryID"
        )
        WHERE "categoryID" IN (
          SELECT "duplicateCategory"."id"
          FROM (
            SELECT "normalizedName", MIN("id") AS "keptID"
            FROM "sessionCategories"
            GROUP BY "normalizedName"
            HAVING COUNT(*) > 1
          ) AS "duplicates"
          INNER JOIN "sessionCategories" AS "duplicateCategory"
            ON "duplicateCategory"."normalizedName" = "duplicates"."normalizedName"
          WHERE "duplicateCategory"."id" <> "duplicates"."keptID"
        )
        """
    )
    .execute(db)

    try #sql(
        """
        DELETE FROM "sessionTaskCategories"
        WHERE "id" IN (
          SELECT "duplicateLinks"."id"
          FROM "sessionTaskCategories" AS "duplicateLinks"
          INNER JOIN (
            SELECT
              "taskID",
              "categoryID",
              MIN("id") AS "keptID"
            FROM "sessionTaskCategories"
            GROUP BY "taskID", "categoryID"
            HAVING COUNT(*) > 1
          ) AS "deduplicated"
            ON "deduplicated"."taskID" = "duplicateLinks"."taskID"
           AND "deduplicated"."categoryID" = "duplicateLinks"."categoryID"
          WHERE "duplicateLinks"."id" <> "deduplicated"."keptID"
        )
        """
    )
    .execute(db)

    try #sql(
        """
        DELETE FROM "sessionCategories"
        WHERE "id" IN (
          SELECT "duplicateCategory"."id"
          FROM "sessionCategories" AS "duplicateCategory"
          INNER JOIN (
            SELECT "normalizedName", MIN("id") AS "keptID"
            FROM "sessionCategories"
            GROUP BY "normalizedName"
            HAVING COUNT(*) > 1
          ) AS "duplicates"
            ON "duplicates"."normalizedName" = "duplicateCategory"."normalizedName"
          WHERE "duplicateCategory"."id" <> "duplicates"."keptID"
        )
        """
    )
    .execute(db)
}
