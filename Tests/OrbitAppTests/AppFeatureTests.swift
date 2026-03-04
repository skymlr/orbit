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
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.sessionTaskEditTapped(task.id)) {
            $0.captureDraft.markdown = task.markdown
            $0.captureDraft.priority = task.priority
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID, projectBCategoryID]
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
            $0.captureWindowFocusRequest = 1
        }
    }

    @Test
    func captureTappedWithActiveSessionOpensCaptureWithoutWorkspaceFocus() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])

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
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])

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
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
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
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID]
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
        }
    }

    @Test
    func endSessionTappedPreparesDraftAndFocusesWorkspace() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
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
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
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
    func sessionWindowBoundaryReachedWorkspaceOpenEndsAndStartsNextSession() async {
        let tracker = SessionWindowTransitionTracker()
        let clock = TestClock()

        let staleSessionID = UUID(uuidString: "5A3D9A4E-22D4-41B0-995E-137377F7B15E")!
        let nextSessionID = UUID(uuidString: "4E557F5F-A4C1-42FA-9E58-7AF737D688F2")!
        let staleStartedAt = Date(timeIntervalSince1970: 1_700_000_000) // afternoon
        let rolloverNow = Date(timeIntervalSince1970: 1_700_010_000) // evening

        let stale = makeSession(
            id: staleSessionID,
            startedAt: staleStartedAt,
            taskCategoryIDs: [projectACategoryID]
        )
        let next = makeSession(
            id: nextSessionID,
            startedAt: rolloverNow,
            taskCategoryIDs: [projectBCategoryID]
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
        repository.startSession = { startedAt in
            await tracker.recordStart(at: startedAt)
            return next
        }
        repository.loadActiveSession = { next }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = rolloverNow
            $0.continuousClock = clock
        }

        await store.send(.sessionWindowBoundaryReached) {
            $0.endSessionDraft = nil
            $0.windowDestinations.remove(.captureWindow)
            $0.sessionWindowTransitionState = .inProgress(from: .afternoon, to: .evening)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = next
            $0.taskDrafts = [
                AppFeature.State.TaskDraft(
                    id: next.tasks[0].id,
                    categories: next.tasks[0].categories,
                    markdown: next.tasks[0].markdown,
                    priority: next.tasks[0].priority,
                    completedAt: next.tasks[0].completedAt,
                    carriedFromTaskID: next.tasks[0].carriedFromTaskID,
                    carriedFromSessionName: next.tasks[0].carriedFromSessionName,
                    createdAt: next.tasks[0].createdAt
                )
            ]
            $0.captureDraft.selectedCategoryIDs = [projectBCategoryID]
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.sessionWindowTransitionCompleted) {
            $0.sessionWindowTransitionState = nil
        }
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
        }

        let endReasons = await tracker.endReasons()
        #expect(endReasons == [.timeWindow])
        #expect(await tracker.startCount() == 1)

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
    func sessionWindowBoundaryReachedWorkspaceClosedEndsOnly() async {
        let tracker = SessionWindowTransitionTracker()

        let staleSessionID = UUID(uuidString: "60192424-8E52-4C4C-8996-C2EE8E35780D")!
        let staleStartedAt = Date(timeIntervalSince1970: 1_700_000_000) // afternoon
        let rolloverNow = Date(timeIntervalSince1970: 1_700_010_000) // evening

        let stale = makeSession(
            id: staleSessionID,
            startedAt: staleStartedAt,
            taskCategoryIDs: [projectACategoryID]
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
        repository.startSession = { startedAt in
            await tracker.recordStart(at: startedAt)
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
        #expect(store.state.sessionWindowTransitionState == nil)
    }

    @Test
    func sessionWindowBoundaryReachedFailureShowsBlockingErrorAndRetryStartsSession() async {
        let clock = TestClock()
        let staleSessionID = UUID(uuidString: "9BA5A197-0FC3-49D5-A716-B1C467EA95C3")!
        let nextSessionID = UUID(uuidString: "F7E546B4-C8CB-47F5-BEA6-A72020AA75AA")!
        let staleStartedAt = Date(timeIntervalSince1970: 1_700_000_000) // afternoon
        let rolloverNow = Date(timeIntervalSince1970: 1_700_010_000) // evening

        let stale = makeSession(
            id: staleSessionID,
            startedAt: staleStartedAt,
            taskCategoryIDs: [projectACategoryID]
        )
        let next = makeSession(
            id: nextSessionID,
            startedAt: rolloverNow,
            taskCategoryIDs: [projectBCategoryID]
        )

        var initial = AppFeature.State()
        initial.activeSession = stale
        initial.categories = sampleCategories
        initial.windowDestinations = [.workspaceWindow]

        let tracker = SessionWindowTransitionTracker()
        let failureState = SessionWindowFailureState(
            shouldFailBoundary: true,
            loadedAfterFailure: false
        )
        var repository = FocusRepository.testValue
        repository.endSession = { _, _, reason, _ in
            await tracker.recordEnd(reason: reason)
            if await failureState.shouldFailBoundary() {
                throw NSError(
                    domain: "OrbitTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Boundary transition failed"]
                )
            }
            return stale
        }
        repository.startSession = { startedAt in
            await tracker.recordStart(at: startedAt)
            return next
        }
        repository.loadActiveSession = {
            if await failureState.shouldFailBoundary() {
                return await failureState.loadedAfterFailure() ? nil : stale
            }
            return next
        }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = rolloverNow
            $0.continuousClock = clock
        }

        await store.send(.sessionWindowBoundaryReached) {
            $0.sessionWindowTransitionState = .inProgress(from: .afternoon, to: .evening)
        }
        await failureState.setLoadedAfterFailure(true)
        await store.receive(\.sessionWindowTransitionFailed) {
            $0.sessionWindowTransitionState = .failed(
                from: .afternoon,
                to: .evening,
                message: "Boundary transition failed"
            )
        }
        await store.receive(\.loadActiveSessionResponse) {
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
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID]
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        await failureState.setShouldFailBoundary(false)
        await store.send(.sessionWindowTransitionRetryTapped) {
            $0.sessionWindowTransitionState = .inProgress(from: .afternoon, to: .evening)
        }
        await store.receive(\.sessionWindowBoundaryReached)
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = next
            $0.taskDrafts = [
                AppFeature.State.TaskDraft(
                    id: next.tasks[0].id,
                    categories: next.tasks[0].categories,
                    markdown: next.tasks[0].markdown,
                    priority: next.tasks[0].priority,
                    completedAt: next.tasks[0].completedAt,
                    carriedFromTaskID: next.tasks[0].carriedFromTaskID,
                    carriedFromSessionName: next.tasks[0].carriedFromSessionName,
                    createdAt: next.tasks[0].createdAt
                )
            ]
            $0.captureDraft.selectedCategoryIDs = [projectBCategoryID]
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.sessionWindowTransitionCompleted) {
            $0.sessionWindowTransitionState = nil
        }
        await store.receive(\.settingsDataResponse)

        #expect(await tracker.startCount() == 1)

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
    func staleActiveSessionOnLoadTriggersImmediateBoundaryRollover() async {
        let clock = TestClock()
        let staleSessionID = UUID(uuidString: "05836C31-09C2-451A-B7A0-4D040D508A4C")!
        let staleStartedAt = Date(timeIntervalSince1970: 1_700_000_000) // afternoon
        let rolloverNow = Date(timeIntervalSince1970: 1_700_010_000) // evening

        let stale = makeSession(
            id: staleSessionID,
            startedAt: staleStartedAt,
            taskCategoryIDs: [projectACategoryID]
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
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID]
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
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
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
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID]
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
    func captureSubmitTappedWithoutEditModeShowsFailureToastWhenSaveFails() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
        let toastID = UUID(uuidString: "BFF9F609-C1F5-4584-8FA0-C64A430D30F2")!
        let clock = TestClock()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.markdown = "New task body"
        initial.captureDraft.priority = .low
        initial.captureDraft.selectedCategoryIDs = [projectACategoryID]
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
                selectedCategoryIDs: [projectACategoryID]
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
    func settingsExportAllTappedWithNoCompletedSessionsShowsFailureToast() async {
        let toastID = UUID(uuidString: "58D6FB1D-0A12-4D3E-B12A-17448DA0EED6")!
        let clock = TestClock()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .constant(toastID)
        }

        await store.send(.settingsExportAllTapped(URL(fileURLWithPath: "/tmp/orbit-export")))
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .failure,
                message: "No completed sessions to export"
            )
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }
    }

    @Test
    func settingsAddCategoryTappedWithDuplicateOrInvalidValueShowsFailureToast() async {
        let toastID = UUID(uuidString: "1A91951B-35A7-43A8-B4DC-4EA2463569FA")!
        let clock = TestClock()

        var repository = FocusRepository.testValue
        repository.addCategory = { _, _ in nil }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.focusRepository = repository
            $0.uuid = .constant(toastID)
        }

        await store.send(.settingsAddCategoryTapped("project-a", "#58B5FF"))
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .failure,
                message: "Category already exists or name is invalid"
            )
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
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

    @Test
    func captureSubmitTappedInEditModeUpdatesExistingTask() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
        let task = active.tasks[0]
        let tracker = TaskMutationTracker()
        let toastID = UUID(uuidString: "5BE35653-3538-45D1-9DA3-42528E04D3DB")!
        let clock = TestClock()

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
                selectedCategoryIDs: [projectBCategoryID, projectACategoryID]
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
        #expect(counts.updatedCategories == [[projectBCategoryID, projectACategoryID]])
        #expect(counts.created.isEmpty)
    }

    @Test
    func captureSubmitTappedWithoutEditModeCreatesNewTask() async {
        let active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
        let tracker = TaskMutationTracker()
        let toastID = UUID(uuidString: "B5DFE991-8BCE-45B2-910D-1768030A2184")!
        let createdTaskID = UUID(uuidString: "5F7B07B6-D730-4C6D-9A80-53E4597504BF")!
        let clock = TestClock()

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
                selectedCategoryIDs: [projectACategoryID, projectBCategoryID]
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
        var active = makeActiveSession(taskCategoryIDs: [projectACategoryID])
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
        #expect(counts.updatedCategories == [[projectACategoryID]])
        #expect(counts.updatedMarkdowns == ["- [x] Launch\n- [x] Review"])
        #expect(store.state.toast == nil)
    }

    @Test
    func sessionTaskCategoryFilterToggleUpdatesState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.sessionTaskCategoryFilterToggled(projectACategoryID)) {
            $0.selectedTaskCategoryFilterIDs = [projectACategoryID]
        }

        await store.send(.sessionTaskCategoryFilterToggled(projectACategoryID)) {
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

        await store.send(.sessionTaskCategoryFilterToggled(projectACategoryID)) {
            $0.selectedTaskCategoryFilterIDs = [projectACategoryID]
        }
        await store.send(.sessionTaskCategoryFilterToggled(projectBCategoryID)) {
            $0.selectedTaskCategoryFilterIDs = [projectACategoryID, projectBCategoryID]
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
        #expect(counts.updatedCategories == [[projectACategoryID]])
        #expect(counts.updatedMarkdowns == [task.markdown])
    }

    @Test
    func loadActiveSessionDefaultsCaptureCategoryToMostRecentTaskCategories() async {
        let clock = TestClock()
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
            $0.captureDraft.selectedCategoryIDs = [projectBCategoryID, projectACategoryID]
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

actor SessionWindowFailureState {
    private var shouldFail: Bool
    private var didLoadAfterFailure: Bool

    init(shouldFailBoundary: Bool, loadedAfterFailure: Bool) {
        self.shouldFail = shouldFailBoundary
        self.didLoadAfterFailure = loadedAfterFailure
    }

    func shouldFailBoundary() -> Bool {
        shouldFail
    }

    func setShouldFailBoundary(_ value: Bool) {
        shouldFail = value
    }

    func loadedAfterFailure() -> Bool {
        didLoadAfterFailure
    }

    func setLoadedAfterFailure(_ value: Bool) {
        didLoadAfterFailure = value
    }
}

private enum AppFeatureTestError: Error {
    case failed
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

private func makeSession(
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
