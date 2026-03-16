import ComposableArchitecture
import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

@MainActor
struct AppFeatureSessionTests {
    @Test
    func sessionTaskCompletionToggledPersistsState() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
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
            $0.selectedTaskCategoryFilterIDs = []
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
    func sessionTaskChecklistLineToggledPersistsMarkdown() async {
        var active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        active.tasks[0].markdown = "- [ ] Launch\n- [x] Review"
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
                completedAt: task.completedAt,
                carriedFromTaskID: task.carriedFromTaskID,
                carriedFromSessionName: task.carriedFromSessionName,
                createdAt: task.createdAt
            )
        ]

        var repository = FocusRepository.testValue
        repository.updateTask = { taskID, markdown, _, categoryIDs, _ in
            await tracker.recordUpdate(
                taskID: taskID,
                categoryIDs: categoryIDs,
                markdown: markdown
            )
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

        await store.send(.sessionTaskChecklistLineToggled(task.id, 0)) {
            $0.taskDrafts[id: task.id]?.markdown = "- [x] Launch\n- [x] Review"
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(selectedCategoryIDs: [])
            $0.selectedTaskCategoryFilterIDs = []
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        let counts = await tracker.counts()
        #expect(counts.updated == [task.id])
        #expect(counts.updatedCategories == [[appFeatureProjectACategoryID]])
        #expect(counts.updatedMarkdowns == ["- [x] Launch\n- [x] Review"])
        #expect(store.state.toast == nil)
    }

    @Test
    func sessionTaskCategoryFilterToggleUpdatesState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.sessionTaskCategoryFilterToggled(appFeatureProjectACategoryID)) {
            $0.selectedTaskCategoryFilterIDs = [appFeatureProjectACategoryID]
        }

        await store.send(.sessionTaskCategoryFilterToggled(appFeatureProjectACategoryID)) {
            $0.selectedTaskCategoryFilterIDs = []
        }
    }

    @Test
    func sessionTaskPriorityFilterToggleUpdatesState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.sessionTaskPriorityFilterToggled(.medium)) {
            $0.selectedTaskPriorityFilters = [.medium]
        }

        await store.send(.sessionTaskPriorityFilterToggled(.medium)) {
            $0.selectedTaskPriorityFilters = []
        }
    }

    @Test
    func taskFiltersAllowMultipleSelectionsAndClearAll() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.sessionTaskCategoryFilterToggled(appFeatureProjectACategoryID)) {
            $0.selectedTaskCategoryFilterIDs = [appFeatureProjectACategoryID]
        }
        await store.send(.sessionTaskCategoryFilterToggled(appFeatureProjectBCategoryID)) {
            $0.selectedTaskCategoryFilterIDs = [appFeatureProjectACategoryID, appFeatureProjectBCategoryID]
        }

        await store.send(.sessionTaskPriorityFilterToggled(.high)) {
            $0.selectedTaskPriorityFilters = [.high]
        }
        await store.send(.sessionTaskPriorityFilterToggled(.medium)) {
            $0.selectedTaskPriorityFilters = [.high, .medium]
        }

        await store.send(.sessionTaskFiltersCleared) {
            $0.selectedTaskCategoryFilterIDs = []
            $0.selectedTaskPriorityFilters = []
        }
    }

    @Test
    func sessionTaskPriorityCycleTappedPersistsState() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
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
                completedAt: task.completedAt,
                carriedFromTaskID: task.carriedFromTaskID,
                carriedFromSessionName: task.carriedFromSessionName,
                createdAt: task.createdAt
            )
        ]

        var repository = FocusRepository.testValue
        repository.updateTask = { taskID, markdown, _, categoryIDs, _ in
            await tracker.recordUpdate(
                taskID: taskID,
                categoryIDs: categoryIDs,
                markdown: markdown
            )
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_300)
        }

        await store.send(.sessionTaskPriorityCycleTapped(task.id))
        await store.receive(\.sessionTaskPrioritySetTapped) {
            $0.taskDrafts[id: task.id]?.priority = .none
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(selectedCategoryIDs: [])
            $0.selectedTaskCategoryFilterIDs = []
            $0.selectedTaskPriorityFilters = []
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        let counts = await tracker.counts()
        #expect(counts.updated == [task.id])
        #expect(counts.updatedCategories == [[appFeatureProjectACategoryID]])
        #expect(counts.updatedMarkdowns == [task.markdown])
    }
}
