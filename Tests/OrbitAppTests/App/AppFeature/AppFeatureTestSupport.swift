import Foundation
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

actor TaskMutationTracker {
    private(set) var created: [UUID] = []
    private(set) var createdCategories: [[UUID]] = []
    private(set) var updated: [UUID] = []
    private(set) var updatedCategories: [[UUID]] = []
    private(set) var updatedMarkdowns: [String] = []
    private(set) var completedTaskIDs: [UUID] = []
    private(set) var completedFlags: [Bool] = []

    func recordCreate(sessionID: UUID, categoryIDs: [UUID]) {
        created.append(sessionID)
        createdCategories.append(categoryIDs)
    }

    func recordUpdate(taskID: UUID, categoryIDs: [UUID], markdown: String? = nil) {
        updated.append(taskID)
        updatedCategories.append(categoryIDs)
        if let markdown {
            updatedMarkdowns.append(markdown)
        }
    }

    func recordCompletion(taskID: UUID, isCompleted: Bool) {
        completedTaskIDs.append(taskID)
        completedFlags.append(isCompleted)
    }

    func counts() -> (
        created: [UUID],
        createdCategories: [[UUID]],
        updated: [UUID],
        updatedCategories: [[UUID]],
        updatedMarkdowns: [String],
        completedTaskIDs: [UUID],
        completedFlags: [Bool]
    ) {
        (
            created,
            createdCategories,
            updated,
            updatedCategories,
            updatedMarkdowns,
            completedTaskIDs,
            completedFlags
        )
    }
}

actor MarkdownExportTracker {
    private var latestExport: (sessionIDs: [UUID], directoryURL: URL)?

    func record(sessionIDs: [UUID], directoryURL: URL) {
        latestExport = (sessionIDs, directoryURL)
    }

    func export() -> (sessionIDs: [UUID], directoryURL: URL)? {
        latestExport
    }
}

actor SessionWindowTransitionTracker {
    private(set) var endReasonValues: [SessionEndReason] = []
    private(set) var startTimes: [Date] = []

    func recordEnd(reason: SessionEndReason) {
        endReasonValues.append(reason)
    }

    func recordStart(at date: Date) {
        startTimes.append(date)
    }

    func endReasons() -> [SessionEndReason] {
        endReasonValues
    }

    func startCount() -> Int {
        startTimes.count
    }
}

enum AppFeatureTestError: Error {
    case failed
}

let appFeatureProjectACategoryID = UUID(uuidString: "3261E8B5-4302-4D32-9FDF-F5D4AB4AF4D9")!
let appFeatureProjectBCategoryID = UUID(uuidString: "A4E2AC92-241D-40A1-AB2B-33804D08EE18")!

var sampleCategories: [SessionCategoryRecord] {
    [
        SessionCategoryRecord(
            id: appFeatureProjectACategoryID,
            name: "project-a",
            normalizedName: "project-a",
            colorHex: "#58B5FF"
        ),
        SessionCategoryRecord(
            id: appFeatureProjectBCategoryID,
            name: "project-b",
            normalizedName: "project-b",
            colorHex: "#7ED957"
        )
    ]
}

func noteCategories(_ ids: [UUID]) -> [NoteCategoryRecord] {
    let byID = Dictionary(uniqueKeysWithValues: sampleCategories.map { ($0.id, $0) })
    return ids.compactMap { id in
        guard let category = byID[id] else { return nil }
        return NoteCategoryRecord(id: category.id, name: category.name, colorHex: category.colorHex)
    }
}

func makeActiveSession(
    taskCategoryIDs: [UUID] = []
) -> FocusSessionRecord {
    let task = FocusTaskRecord(
        id: UUID(uuidString: "A6E2C2D2-53AF-4D10-ACE2-761B700A1DB1")!,
        sessionID: UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!,
        categories: noteCategories(taskCategoryIDs),
        markdown: "Ship Orbit session window",
        priority: .high,
        completedAt: nil,
        carriedFromTaskID: nil,
        carriedFromSessionName: nil,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    return FocusSessionRecord(
        id: task.sessionID,
        name: "2026-02-26 10:30",
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        endedAt: nil,
        endedReason: nil,
        tasks: [task]
    )
}

func makeSession(
    id: UUID,
    startedAt: Date,
    taskCategoryIDs: [UUID] = []
) -> FocusSessionRecord {
    let task = FocusTaskRecord(
        id: UUID(),
        sessionID: id,
        categories: noteCategories(taskCategoryIDs),
        markdown: "Window transition task",
        priority: .high,
        completedAt: nil,
        carriedFromTaskID: nil,
        carriedFromSessionName: nil,
        createdAt: startedAt,
        updatedAt: startedAt
    )

    return FocusSessionRecord(
        id: id,
        name: FocusDefaults.defaultSessionName(startedAt: startedAt),
        startedAt: startedAt,
        endedAt: nil,
        endedReason: nil,
        tasks: [task]
    )
}
