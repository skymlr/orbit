import ComposableArchitecture
import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

@MainActor
struct AppFeatureLifecycleTests {
    @Test
    func endSessionTappedPreparesDraftAndFocusesWorkspace() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        let draftID = UUID(uuidString: "091E5E28-D32B-4CC2-AEB9-D2FE85B3C10E")!

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.windowDestinations = [.captureWindow]
        initial.workspaceWindowFocusRequest = 2

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .constant(draftID)
        }

        await store.send(.endSessionTapped) {
            $0.endSessionDraft = AppFeature.State.EndSessionDraft(
                id: draftID,
                name: active.name
            )
            $0.windowDestinations.remove(.captureWindow)
            $0.windowDestinations.insert(.workspaceWindow)
            $0.workspaceWindowFocusRequest = 3
        }
    }

    @Test
    func endSessionTappedDoesNotRefocusWhenWorkspaceAlreadyOpen() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        let draftID = UUID(uuidString: "A35E14B7-4A72-406D-BF80-68D2CDA85B7B")!

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.windowDestinations = [.workspaceWindow]
        initial.workspaceWindowFocusRequest = 5

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .constant(draftID)
        }

        await store.send(.endSessionTapped) {
            $0.endSessionDraft = AppFeature.State.EndSessionDraft(
                id: draftID,
                name: active.name
            )
            $0.workspaceWindowFocusRequest = 5
        }
    }

    @Test
    func sessionWindowBoundaryReachedWorkspaceOpenEndsOnly() async {
        let tracker = SessionWindowTransitionTracker()

        let staleSessionID = UUID(uuidString: "5A3D9A4E-22D4-41B0-995E-137377F7B15E")!
        let staleStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let rolloverNow = Date(timeIntervalSince1970: 1_700_010_000)

        let stale = makeSession(
            id: staleSessionID,
            startedAt: staleStartedAt,
            taskCategoryIDs: [appFeatureProjectACategoryID]
        )

        var initial = AppFeature.State()
        initial.activeSession = stale
        initial.categories = sampleCategories
        initial.windowDestinations = [.workspaceWindow, .captureWindow]
        initial.endSessionDraft = .init(name: "Draft Name")

        var repository = FocusRepository.testValue
        repository.endSession = { _, _, reason, _ in
            await tracker.recordEnd(reason: reason)
            return stale
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = rolloverNow
        }

        await store.send(.sessionWindowBoundaryReached) {
            $0.endSessionDraft = nil
            $0.windowDestinations.remove(.captureWindow)
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

        let endReasons = await tracker.endReasons()
        #expect(endReasons == [.timeWindow])
        #expect(await tracker.startCount() == 0)
    }

    @Test
    func sessionWindowBoundaryReachedWorkspaceClosedEndsOnly() async {
        let tracker = SessionWindowTransitionTracker()

        let staleSessionID = UUID(uuidString: "60192424-8E52-4C4C-8996-C2EE8E35780D")!
        let staleStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let rolloverNow = Date(timeIntervalSince1970: 1_700_010_000)

        let stale = makeSession(
            id: staleSessionID,
            startedAt: staleStartedAt,
            taskCategoryIDs: [appFeatureProjectACategoryID]
        )

        var initial = AppFeature.State()
        initial.activeSession = stale
        initial.categories = sampleCategories
        initial.windowDestinations = [.captureWindow]
        initial.endSessionDraft = .init(name: "Draft Name")

        var repository = FocusRepository.testValue
        repository.endSession = { _, _, reason, _ in
            await tracker.recordEnd(reason: reason)
            return stale
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = rolloverNow
        }

        await store.send(.sessionWindowBoundaryReached) {
            $0.endSessionDraft = nil
            $0.windowDestinations.remove(.captureWindow)
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

        #expect(await tracker.endReasons() == [.timeWindow])
        #expect(await tracker.startCount() == 0)
    }

    @Test
    func staleActiveSessionOnLoadTriggersImmediateBoundaryRollover() async {
        let clock = TestClock()
        let staleSessionID = UUID(uuidString: "05836C31-09C2-451A-B7A0-4D040D508A4C")!
        let staleStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let rolloverNow = Date(timeIntervalSince1970: 1_700_010_000)

        let stale = makeSession(
            id: staleSessionID,
            startedAt: staleStartedAt,
            taskCategoryIDs: [appFeatureProjectACategoryID]
        )

        let tracker = SessionWindowTransitionTracker()
        var repository = FocusRepository.testValue
        repository.endSession = { _, _, reason, _ in
            await tracker.recordEnd(reason: reason)
            return stale
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        var initial = AppFeature.State()
        initial.categories = sampleCategories

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = rolloverNow
            $0.continuousClock = clock
        }

        await store.send(.loadActiveSessionResponse(stale)) {
            $0.activeSession = stale
            $0.taskDrafts = [
                AppFeature.State.TaskDraft(
                    id: stale.tasks[0].id,
                    categories: stale.tasks[0].categories,
                    markdown: stale.tasks[0].markdown,
                    priority: stale.tasks[0].priority,
                    completedAt: stale.tasks[0].completedAt,
                    carriedFromTaskID: stale.tasks[0].carriedFromTaskID,
                    carriedFromSessionName: stale.tasks[0].carriedFromSessionName,
                    createdAt: stale.tasks[0].createdAt
                )
            ]
            $0.captureDraft.selectedCategoryIDs = [appFeatureProjectACategoryID]
        }
        await store.receive(\.sessionWindowBoundaryReached)
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

        #expect(await tracker.endReasons() == [.timeWindow])
    }

    @Test
    func startSessionTappedShowsSuccessToastAndAutoDismisses() async {
        let active = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        let task = active.tasks[0]
        let toastID = UUID(uuidString: "9289D0E7-BE5C-4FA0-9F84-F793A3BF9D7A")!
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
            $0.continuousClock = clock
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .constant(toastID)
        }

        await store.send(.startSessionTapped) {
            $0.windowDestinations.insert(.workspaceWindow)
        }
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
        await store.receive(\.openWorkspaceTapped) {
            $0.workspaceWindowFocusRequest = 1
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .success,
                message: "Session started"
            )
        }
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
        }

        await clock.advance(by: .milliseconds(2_500))
        await store.receive(\.toastAutoDismissFired) {
            $0.toast = nil
        }
        await store.send(.loadActiveSessionResponse(nil)) {
            $0.activeSession = nil
            $0.taskDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(selectedCategoryIDs: [])
            $0.selectedTaskCategoryFilterIDs = []
            $0.selectedTaskPriorityFilters = []
        }
    }

    @Test
    func showToastReplacesCurrentToastAndCancelsPreviousAutoDismiss() async {
        let firstToastID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let secondToastID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let clock = TestClock()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .incrementing
        }

        await store.send(.showToast(tone: .success, message: "Hotkeys saved")) {
            $0.toast = AppFeature.State.Toast(
                id: firstToastID,
                tone: .success,
                message: "Hotkeys saved"
            )
        }
        await store.send(.showToast(tone: .success, message: "Hotkeys reset to defaults")) {
            $0.toast = AppFeature.State.Toast(
                id: secondToastID,
                tone: .success,
                message: "Hotkeys reset to defaults"
            )
        }

        await clock.advance(by: .milliseconds(2_500))
        await store.receive(\.toastAutoDismissFired) {
            $0.toast = nil
        }
    }
}
