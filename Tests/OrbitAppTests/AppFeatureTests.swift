import ComposableArchitecture
import Foundation
import Testing
@testable import OrbitApp

@MainActor
struct AppFeatureTests {
    @Test
    func sessionTaskEditTappedPrefillsCaptureAndOpensWindow() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID, projectBCategoryID])
        let task = active.tasks[0]

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.taskDrafts = [
            AppFeature.State.TaskDraft(
                id: task.id,
                categories: task.categories,
                markdown: task.markdown,
                priority: task.priority,
                completedAt: task.completedAt,
                carriedFromTaskID: task.carriedFromTaskID,
                carriedFromSessionName: task.carriedFromSessionName,
                createdAt: task.createdAt
            )
        ]
        initial.categories = sampleCategories

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.sessionTaskEditTapped(task.id)) {
            $0.captureDraft.markdown = task.markdown
            $0.captureDraft.priority = task.priority
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID, projectBCategoryID]
            $0.captureDraft.editingTaskID = task.id
            $0.windowDestinations.insert(.captureWindow)
        }
    }

    @Test
    func sessionAddTaskTappedResetsEditContext() async {
        var initial = AppFeature.State()
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "Existing markdown"
        initial.captureDraft.priority = .high
        initial.captureDraft.selectedCategoryIDs = [projectBCategoryID]
        initial.captureDraft.editingTaskID = UUID(uuidString: "44D1A620-53B0-49D7-9B60-2A1BA056EA28")!

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.sessionAddTaskTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [projectBCategoryID]
            )
            $0.windowDestinations.insert(.captureWindow)
        }
    }

    @Test
    func captureSubmitTappedInEditModeUpdatesExistingTask() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
        let task = active.tasks[0]
        let tracker = TaskMutationTracker()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "Updated body"
        initial.captureDraft.priority = .medium
        initial.captureDraft.selectedCategoryIDs = [projectBCategoryID, projectACategoryID]
        initial.captureDraft.editingTaskID = task.id
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateTask = { taskID, _, _, categoryIDs, _ in
            await tracker.recordUpdate(taskID: taskID, categoryIDs: categoryIDs)
            return nil
        }
        repository.createTask = { sessionID, _, _, categoryIDs, _ in
            await tracker.recordCreate(sessionID: sessionID, categoryIDs: categoryIDs)
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [projectBCategoryID, projectACategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: []
            )
            $0.selectedTaskCategoryFilter = .all
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        let counts = await tracker.counts()
        #expect(counts.updated == [task.id])
        #expect(counts.updatedCategories == [[projectBCategoryID, projectACategoryID]])
        #expect(counts.created.isEmpty)
    }

    @Test
    func captureSubmitTappedWithoutEditModeCreatesNewTask() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
        let tracker = TaskMutationTracker()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "New task body"
        initial.captureDraft.priority = .low
        initial.captureDraft.selectedCategoryIDs = [projectACategoryID, projectBCategoryID]
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateTask = { taskID, _, _, categoryIDs, _ in
            await tracker.recordUpdate(taskID: taskID, categoryIDs: categoryIDs)
            return nil
        }
        repository.createTask = { sessionID, _, _, categoryIDs, _ in
            await tracker.recordCreate(sessionID: sessionID, categoryIDs: categoryIDs)
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [projectACategoryID, projectBCategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: []
            )
            $0.selectedTaskCategoryFilter = .all
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        let counts = await tracker.counts()
        #expect(counts.created == [active.id])
        #expect(counts.createdCategories == [[projectACategoryID, projectBCategoryID]])
        #expect(counts.updated.isEmpty)
    }

    @Test
    func sessionTaskCompletionToggledPersistsState() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
        let task = active.tasks[0]
        let tracker = TaskMutationTracker()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.taskDrafts = [
            AppFeature.State.TaskDraft(
                id: task.id,
                categories: task.categories,
                markdown: task.markdown,
                priority: task.priority,
                completedAt: nil,
                carriedFromTaskID: nil,
                carriedFromSessionName: nil,
                createdAt: task.createdAt
            )
        ]

        var repository = FocusRepository.testValue
        repository.setTaskCompletion = { taskID, isCompleted, _ in
            await tracker.recordCompletion(taskID: taskID, isCompleted: isCompleted)
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_200)
        }

        await store.send(.sessionTaskCompletionToggled(task.id, true)) {
            $0.taskDrafts[id: task.id]?.completedAt = Date(timeIntervalSince1970: 1_700_000_200)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(selectedCategoryIDs: [])
            $0.selectedTaskCategoryFilter = .all
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        let counts = await tracker.counts()
        #expect(counts.completedTaskIDs == [task.id])
        #expect(counts.completedFlags == [true])
    }

    @Test
    func sessionTaskCategoryFilterChangedUpdatesState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.sessionTaskCategoryFilterChangedTapped(.category(projectACategoryID))) {
            $0.selectedTaskCategoryFilter = .category(projectACategoryID)
        }

        await store.send(.sessionTaskCategoryFilterChangedTapped(.all)) {
            $0.selectedTaskCategoryFilter = .all
        }
    }

    @Test
    func loadActiveSessionDefaultsCaptureCategoryToMostRecentTaskCategories() async {
        let olderTask = FocusTaskRecord(
            id: UUID(uuidString: "D10501A3-EB95-4B5D-9F97-C8E35E5BCA61")!,
            sessionID: UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!,
            categories: noteCategories([projectACategoryID]),
            markdown: "Older",
            priority: .none,
            completedAt: nil,
            carriedFromTaskID: nil,
            carriedFromSessionName: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let newerTask = FocusTaskRecord(
            id: UUID(uuidString: "DFBA97DE-5139-49DB-9D03-6F62A2A6A955")!,
            sessionID: olderTask.sessionID,
            categories: noteCategories([projectBCategoryID, projectACategoryID]),
            markdown: "Newer",
            priority: .none,
            completedAt: nil,
            carriedFromTaskID: nil,
            carriedFromSessionName: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let session = FocusSessionRecord(
            id: olderTask.sessionID,
            name: "Two tasks",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: nil,
            endedReason: nil,
            tasks: [olderTask, newerTask]
        )

        var initial = AppFeature.State()
        initial.categories = sampleCategories

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.loadActiveSessionResponse(session)) {
            $0.activeSession = session
            $0.taskDrafts = [
                AppFeature.State.TaskDraft(
                    id: newerTask.id,
                    categories: newerTask.categories,
                    markdown: newerTask.markdown,
                    priority: newerTask.priority,
                    completedAt: newerTask.completedAt,
                    carriedFromTaskID: newerTask.carriedFromTaskID,
                    carriedFromSessionName: newerTask.carriedFromSessionName,
                    createdAt: newerTask.createdAt
                ),
                AppFeature.State.TaskDraft(
                    id: olderTask.id,
                    categories: olderTask.categories,
                    markdown: olderTask.markdown,
                    priority: olderTask.priority,
                    completedAt: olderTask.completedAt,
                    carriedFromTaskID: olderTask.carriedFromTaskID,
                    carriedFromSessionName: olderTask.carriedFromSessionName,
                    createdAt: olderTask.createdAt
                )
            ]
            $0.captureDraft.selectedCategoryIDs = [projectBCategoryID, projectACategoryID]
        }

        await store.send(.loadActiveSessionResponse(nil)) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(selectedCategoryIDs: [])
            $0.selectedTaskCategoryFilter = .all
        }
    }
}

actor TaskMutationTracker {
    private(set) var created: [UUID] = []
    private(set) var createdCategories: [[UUID]] = []
    private(set) var updated: [UUID] = []
    private(set) var updatedCategories: [[UUID]] = []
    private(set) var completedTaskIDs: [UUID] = []
    private(set) var completedFlags: [Bool] = []

    func recordCreate(sessionID: UUID, categoryIDs: [UUID]) {
        created.append(sessionID)
        createdCategories.append(categoryIDs)
    }

    func recordUpdate(taskID: UUID, categoryIDs: [UUID]) {
        updated.append(taskID)
        updatedCategories.append(categoryIDs)
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
        completedTaskIDs: [UUID],
        completedFlags: [Bool]
    ) {
        (created, createdCategories, updated, updatedCategories, completedTaskIDs, completedFlags)
    }
}

private let projectACategoryID = UUID(uuidString: "3261E8B5-4302-4D32-9FDF-F5D4AB4AF4D9")!
private let projectBCategoryID = UUID(uuidString: "A4E2AC92-241D-40A1-AB2B-33804D08EE18")!

private var sampleCategories: [SessionCategoryRecord] {
    [
        SessionCategoryRecord(
            id: projectACategoryID,
            name: "project-a",
            normalizedName: "project-a",
            colorHex: "#58B5FF"
        ),
        SessionCategoryRecord(
            id: projectBCategoryID,
            name: "project-b",
            normalizedName: "project-b",
            colorHex: "#7ED957"
        )
    ]
}

private func noteCategories(_ ids: [UUID]) -> [NoteCategoryRecord] {
    let byID = Dictionary(uniqueKeysWithValues: sampleCategories.map { ($0.id, $0) })
    return ids.compactMap { id in
        guard let category = byID[id] else { return nil }
        return NoteCategoryRecord(id: category.id, name: category.name, colorHex: category.colorHex)
    }
}

private func makeActiveSession(
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
