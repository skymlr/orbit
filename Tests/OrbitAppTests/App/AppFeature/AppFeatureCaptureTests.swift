import ComposableArchitecture
import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

@MainActor
struct AppFeatureCaptureTests {
    @Test
    func sessionTaskEditTappedPrefillsCaptureAndOpensWindow() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID, appFeatureProjectBCategoryID])
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
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.sessionTaskEditTapped(task.id)) {
            $0.captureDraft.markdown = task.markdown
            $0.captureDraft.priority = task.priority
            $0.captureDraft.selectedCategoryIDs = [appFeatureProjectACategoryID, appFeatureProjectBCategoryID]
            $0.captureDraft.editingTaskID = task.id
            $0.windowDestinations.insert(.captureWindow)
            $0.captureWindowFocusRequest = 1
        }
    }

    @Test
    func sessionAddTaskTappedResetsEditContext() async {
        var initial = AppFeature.State()
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "Existing markdown"
        initial.captureDraft.priority = .high
        initial.captureDraft.selectedCategoryIDs = [appFeatureProjectBCategoryID]
        initial.captureDraft.editingTaskID = UUID(uuidString: "44D1A620-53B0-49D7-9B60-2A1BA056EA28")!

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.sessionAddTaskTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [appFeatureProjectBCategoryID]
            )
            $0.windowDestinations.insert(.captureWindow)
            $0.captureWindowFocusRequest = 1
        }
    }

    @Test
    func captureTappedWithActiveSessionOpensCaptureWithoutWorkspaceFocus() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])

        var initial = AppFeature.State()
        initial.activeSession = active

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.captureTapped) {
            $0.windowDestinations.insert(.captureWindow)
            $0.captureWindowFocusRequest = 1
        }

        #expect(store.state.windowDestinations.contains(.workspaceWindow) == false)
        #expect(store.state.workspaceWindowFocusRequest == 0)
    }

    @Test
    func captureTappedWhileCaptureOpenRequestsRefocus() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.windowDestinations.insert(.captureWindow)
        initial.captureWindowFocusRequest = 2

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.captureTapped) {
            $0.captureWindowFocusRequest = 3
        }

        #expect(store.state.windowDestinations.contains(.captureWindow))
        #expect(store.state.workspaceWindowFocusRequest == 0)
    }

    @Test
    func captureTappedWithoutActiveSessionStartsSessionAndOpensCaptureOnly() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        let task = active.tasks[0]
        let clock = TestClock()

        var initial = AppFeature.State()
        initial.categories = sampleCategories

        var repository = FocusRepository.testValue
        repository.startSession = { _ in active }
        repository.loadActiveSession = { active }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.continuousClock = clock
        }

        await store.send(.captureTapped)
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = active
            $0.taskDrafts = [
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
            $0.captureDraft.selectedCategoryIDs = [appFeatureProjectACategoryID]
        }
        await store.receive(\.captureTapped) {
            $0.windowDestinations.insert(.captureWindow)
            $0.captureWindowFocusRequest = 1
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
        }

        #expect(store.state.windowDestinations.contains(.captureWindow))
        #expect(store.state.windowDestinations.contains(.workspaceWindow) == false)
        #expect(store.state.workspaceWindowFocusRequest == 0)

        await store.send(.loadActiveSessionResponse(nil)) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
            $0.captureDraft = AppFeature.State.CaptureDraft(selectedCategoryIDs: [])
            $0.selectedTaskCategoryFilterIDs = []
            $0.selectedTaskPriorityFilters = []
        }
    }

    @Test
    func captureSubmitTappedWithoutEditModeShowsFailureToastWhenSaveFails() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        let toastID = UUID(uuidString: "BFF9F609-C1F5-4584-8FA0-C64A430D30F2")!
        let clock = TestClock()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "New task body"
        initial.captureDraft.priority = .low
        initial.captureDraft.selectedCategoryIDs = [appFeatureProjectACategoryID]
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.createTask = { _, _, _, _, _ in
            throw AppFeatureTestError.failed
        }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.continuousClock = clock
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .constant(toastID)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [appFeatureProjectACategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .failure,
                message: "Could not save task"
            )
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }
    }

    @Test
    func captureSubmitTappedInEditModeUpdatesExistingTask() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        let task = active.tasks[0]
        let tracker = TaskMutationTracker()
        let toastID = UUID(uuidString: "5BE35653-3538-45D1-9DA3-42528E04D3DB")!
        let clock = TestClock()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "Updated body"
        initial.captureDraft.priority = .medium
        initial.captureDraft.selectedCategoryIDs = [appFeatureProjectBCategoryID, appFeatureProjectACategoryID]
        initial.captureDraft.editingTaskID = task.id
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateTask = { taskID, _, _, categoryIDs, _ in
            await tracker.recordUpdate(taskID: taskID, categoryIDs: categoryIDs)
            return task
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
            $0.continuousClock = clock
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .constant(toastID)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [appFeatureProjectBCategoryID, appFeatureProjectACategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .success,
                message: "Task updated"
            )
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: []
            )
            $0.selectedTaskCategoryFilterIDs = []
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }

        let counts = await tracker.counts()
        #expect(counts.updated == [task.id])
        #expect(counts.updatedCategories == [[appFeatureProjectBCategoryID, appFeatureProjectACategoryID]])
        #expect(counts.created.isEmpty)
    }

    @Test
    func captureSubmitTappedWithoutEditModeCreatesNewTask() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        let tracker = TaskMutationTracker()
        let toastID = UUID(uuidString: "B5DFE991-8BCE-45B2-910D-1768030A2184")!
        let createdTaskID = UUID(uuidString: "5F7B07B6-D730-4C6D-9A80-53E4597504BF")!
        let clock = TestClock()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "New task body"
        initial.captureDraft.priority = .low
        initial.captureDraft.selectedCategoryIDs = [appFeatureProjectACategoryID, appFeatureProjectBCategoryID]
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateTask = { taskID, _, _, categoryIDs, _ in
            await tracker.recordUpdate(taskID: taskID, categoryIDs: categoryIDs)
            return nil
        }
        repository.createTask = { sessionID, _, _, categoryIDs, _ in
            await tracker.recordCreate(sessionID: sessionID, categoryIDs: categoryIDs)
            return FocusTaskRecord(
                id: createdTaskID,
                sessionID: sessionID,
                categories: noteCategories(categoryIDs),
                markdown: "New task body",
                priority: .low,
                completedAt: nil,
                carriedFromTaskID: nil,
                carriedFromSessionName: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .constant(toastID)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [appFeatureProjectACategoryID, appFeatureProjectBCategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .success,
                message: "Task saved"
            )
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: []
            )
            $0.selectedTaskCategoryFilterIDs = []
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }

        let counts = await tracker.counts()
        #expect(counts.created == [active.id])
        #expect(counts.createdCategories == [[appFeatureProjectACategoryID, appFeatureProjectBCategoryID]])
        #expect(counts.updated.isEmpty)
    }

    @Test
    func loadActiveSessionDefaultsCaptureCategoryToMostRecentTaskCategories() async {
        let clock = TestClock()
        let olderTask = FocusTaskRecord(
            id: UUID(uuidString: "D10501A3-EB95-4B5D-9F97-C8E35E5BCA61")!,
            sessionID: UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!,
            categories: noteCategories([appFeatureProjectACategoryID]),
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
            categories: noteCategories([appFeatureProjectBCategoryID, appFeatureProjectACategoryID]),
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
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.continuousClock = clock
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
            $0.captureDraft.selectedCategoryIDs = [appFeatureProjectBCategoryID, appFeatureProjectACategoryID]
        }

        await store.send(.loadActiveSessionResponse(nil)) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(selectedCategoryIDs: [])
            $0.selectedTaskCategoryFilterIDs = []
        }
    }
}
