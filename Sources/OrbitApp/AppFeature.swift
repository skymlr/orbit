import CasePaths
import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    private enum CancelID {
        case inactivityMonitor
        case sessionWindowMonitor
        case hotkeyRegistration
        case toastAutoDismiss
    }

    @CasePathable
    enum WindowDestination: Hashable, Sendable {
        case workspaceWindow
        case captureWindow
    }

    @ObservableState
    struct State: Equatable {
        enum SessionBootstrapState: Equatable {
            case idle
            case loading
            case failed(String)
            case loaded
        }

        struct CaptureDraft: Equatable {
            var markdown = ""
            var priority: NotePriority = .none
            var selectedCategoryIDs: [UUID] = []
            var editingTaskID: UUID?
        }

        struct EndSessionDraft: Equatable, Identifiable {
            var id = UUID()
            var name = ""
        }

        struct TaskDraft: Equatable, Identifiable {
            var id: UUID
            var categories: [NoteCategoryRecord]
            var markdown: String
            var priority: NotePriority
            var completedAt: Date?
            var carriedFromTaskID: UUID?
            var carriedFromSessionName: String?
            var createdAt: Date
        }

        struct Toast: Equatable, Identifiable {
            enum Tone: Equatable {
                case success
                case failure
            }

            var id: UUID
            var tone: Tone
            var message: String
        }

        struct SettingsState: Equatable {
            var sessions: [FocusSessionRecord] = []
            var categories: [SessionCategoryRecord] = []
            var startShortcut = HotkeySettings.default.startShortcut
            var captureShortcut = HotkeySettings.default.captureShortcut
            var captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
        }

        var activeSession: FocusSessionRecord?
        var taskDrafts: IdentifiedArrayOf<TaskDraft> = []

        var categories: [SessionCategoryRecord] = []
        var hotkeys: HotkeySettings = .default

        var captureDraft = CaptureDraft()
        var endSessionDraft: EndSessionDraft?

        var selectedTaskCategoryFilterIDs: Set<UUID> = []
        var selectedTaskPriorityFilters: Set<NotePriority> = []

        var settings = SettingsState()
        var toast: Toast?

        var windowDestinations: Set<WindowDestination> = []
        var workspaceWindowFocusRequest = 0
        var captureWindowFocusRequest = 0
        var sessionBootstrapState: SessionBootstrapState = .idle
        var hasLaunched = false

        var filteredTaskDrafts: [TaskDraft] {
            taskDrafts.filter { draft in
                let categoryMatch: Bool
                if selectedTaskCategoryFilterIDs.isEmpty {
                    categoryMatch = true
                } else {
                    categoryMatch = draft.categories.contains(where: { selectedTaskCategoryFilterIDs.contains($0.id) })
                }

                let priorityMatch: Bool
                if selectedTaskPriorityFilters.isEmpty {
                    priorityMatch = true
                } else {
                    priorityMatch = selectedTaskPriorityFilters.contains(draft.priority)
                }

                return categoryMatch && priorityMatch
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)

        case onLaunch
        case appWillTerminate
        case inactivityTick

        case hotkeyTriggered(HotkeyKind)
        case registerHotkeys(HotkeySettings)

        case startSessionTapped
        case captureTapped
        case openWorkspaceTapped
        case endSessionTapped

        case workspaceWindowClosed
        case captureWindowClosed

        case captureSubmitTapped
        case sessionAddTaskTapped
        case sessionRenameTapped(String)
        case sessionTaskCategoryFilterToggled(UUID)
        case sessionTaskPriorityFilterToggled(NotePriority)
        case sessionTaskFiltersCleared
        case sessionTaskDeleteTapped(UUID)
        case sessionTaskEditTapped(UUID)
        case sessionTaskPriorityCycleTapped(UUID)
        case sessionTaskPrioritySetTapped(UUID, NotePriority)
        case sessionTaskCompletionToggled(UUID, Bool)
        case sessionTaskChecklistLineToggled(UUID, Int)

        case endSessionConfirmTapped(name: String)
        case endSessionCancelTapped
        case autoEndSession
        case sessionWindowBoundaryReached

        case settingsRefreshTapped
        case settingsResetHotkeysTapped
        case settingsSaveHotkeysTapped
        case settingsAddCategoryTapped(String, String)
        case settingsRenameCategoryTapped(UUID, String, String)
        case settingsDeleteCategoryTapped(UUID)
        case settingsRenameSessionTapped(UUID, String)
        case settingsDeleteSessionTapped(UUID)
        case settingsExportAllTapped(URL)
        case settingsExportSessionTapped(UUID, URL)
        case showToast(tone: State.Toast.Tone, message: String)
        case toastAutoDismissFired(UUID)
        case toastDismissTapped
        case retryBootstrapActiveSessionButtonTapped

        case bootstrapActiveSessionLoaded(FocusSessionRecord?)
        case bootstrapActiveSessionFailed(String)
        case loadActiveSessionResponse(FocusSessionRecord?)
        case loadCategoriesResponse([SessionCategoryRecord])
        case settingsDataResponse([FocusSessionRecord], [SessionCategoryRecord])
    }

    @Dependency(\.date.now) var now
    @Dependency(\.focusRepository) var focusRepository
    @Dependency(\.hotkeyManager) var hotkeyManager
    @Dependency(\.hotkeySettingsClient) var hotkeySettingsClient
    @Dependency(\.inactivityClient) var inactivityClient
    @Dependency(\.markdownExportClient) var markdownExportClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onLaunch:
                guard !state.hasLaunched else { return .none }
                state.hasLaunched = true
                state.sessionBootstrapState = .loading

                let hotkeys = hotkeySettingsClient.load()
                state.hotkeys = hotkeys
                state.settings.startShortcut = hotkeys.startShortcut
                state.settings.captureShortcut = hotkeys.captureShortcut
                state.settings.captureNextPriorityShortcut = hotkeys.captureNextPriorityShortcut

                return .merge(
                    .send(.registerHotkeys(hotkeys)),
                    .run { send in
                        do {
                            let activeSession = try await focusRepository.loadActiveSession()
                            await send(.bootstrapActiveSessionLoaded(activeSession))
                        } catch {
                            await send(.bootstrapActiveSessionFailed(error.localizedDescription))
                        }
                    },
                    .run { send in
                        let categories = (try? await focusRepository.listCategories()) ?? []
                        await send(.loadCategoriesResponse(categories))
                    },
                    .send(.settingsRefreshTapped)
                )

            case .appWillTerminate:
                guard let activeSession = state.activeSession else { return .none }
                try? focusRepository.endSessionSync(
                    activeSession.id,
                    nil,
                    .appClosed,
                    now
                )
                state.activeSession = nil
                state.taskDrafts = []
                state.windowDestinations.removeAll()
                state.endSessionDraft = nil
                state.toast = nil
                return .merge(
                    .cancel(id: CancelID.inactivityMonitor),
                    .cancel(id: CancelID.sessionWindowMonitor),
                    .cancel(id: CancelID.hotkeyRegistration),
                    .cancel(id: CancelID.toastAutoDismiss)
                )

            case .inactivityTick:
                guard state.activeSession != nil else { return .none }
                let idleDuration = inactivityClient.idleDuration()
                if idleDuration >= 8 * 60 * 60 {
                    return .send(.autoEndSession)
                }
                return .none

            case let .hotkeyTriggered(kind):
                switch kind {
                case .startSession:
                    return .send(.startSessionTapped)
                case .capture:
                    return .send(.captureTapped)
                }

            case let .registerHotkeys(settings):
                return .run { send in
                    let stream = AsyncStream<HotkeyKind> { continuation in
                        hotkeyManager.register(settings.startShortcut) {
                            continuation.yield(.startSession)
                        }
                        hotkeyManager.register(settings.captureShortcut) {
                            continuation.yield(.capture)
                        }
                        continuation.onTermination = { _ in
                            hotkeyManager.unregister(settings.startShortcut)
                            hotkeyManager.unregister(settings.captureShortcut)
                        }
                    }

                    for await kind in stream {
                        await send(.hotkeyTriggered(kind))
                    }
                }
                .cancellable(id: CancelID.hotkeyRegistration, cancelInFlight: true)

            case .startSessionTapped:
                if state.activeSession != nil {
                    return .send(.openWorkspaceTapped)
                }
                state.windowDestinations.insert(.workspaceWindow)

                return .run { send in
                    do {
                        _ = try await focusRepository.startSession(now)
                        let active = try await focusRepository.loadActiveSession()
                        guard active != nil else {
                            await send(.showToast(tone: .failure, message: "Could not start session"))
                            return
                        }
                        await send(.loadActiveSessionResponse(active))
                        await send(.openWorkspaceTapped)
                        await send(.settingsRefreshTapped)
                        await send(.showToast(tone: .success, message: "Session started"))
                    } catch {
                        await send(.showToast(tone: .failure, message: "Could not start session"))
                    }
                }

            case .captureTapped:
                if state.activeSession != nil {
                    state.windowDestinations.insert(.captureWindow)
                    state.captureWindowFocusRequest &+= 1
                    return .none
                }

                return .run { send in
                    do {
                        _ = try await focusRepository.startSession(now)
                        let active = try await focusRepository.loadActiveSession()
                        guard active != nil else {
                            await send(.showToast(tone: .failure, message: "Could not start session"))
                            return
                        }
                        await send(.loadActiveSessionResponse(active))
                        await send(.captureTapped)
                        await send(.settingsRefreshTapped)
                    } catch {
                        await send(.showToast(tone: .failure, message: "Could not start session"))
                    }
                }

            case .openWorkspaceTapped:
                state.windowDestinations.insert(.workspaceWindow)
                state.workspaceWindowFocusRequest &+= 1
                return .none

            case .endSessionTapped:
                guard let active = state.activeSession else { return .none }
                state.endSessionDraft = State.EndSessionDraft(
                    id: uuid(),
                    name: active.name
                )
                state.windowDestinations.remove(.captureWindow)
                let didOpenWorkspace = state.windowDestinations.insert(.workspaceWindow).inserted
                if didOpenWorkspace {
                    state.workspaceWindowFocusRequest &+= 1
                }
                return .none

            case .workspaceWindowClosed:
                state.windowDestinations.remove(.workspaceWindow)
                return .none

            case .captureWindowClosed:
                state.windowDestinations.remove(.captureWindow)
                state.captureDraft = State.CaptureDraft(
                    selectedCategoryIDs: persistedCaptureCategoryIDs(state)
                )
                return .none

            case .captureSubmitTapped:
                guard let activeSession = state.activeSession else { return .none }
                let markdown = state.captureDraft.markdown
                let priority = state.captureDraft.priority
                let editingTaskID = state.captureDraft.editingTaskID
                let selectedCategoryIDs = normalizedCategoryIDs(
                    state.captureDraft.selectedCategoryIDs,
                    categories: state.categories
                )

                state.captureDraft = State.CaptureDraft(selectedCategoryIDs: selectedCategoryIDs)
                state.windowDestinations.remove(.captureWindow)

                return .run { send in
                    do {
                        if let taskID = editingTaskID {
                            let updatedTask = try await focusRepository.updateTask(
                                taskID,
                                markdown,
                                priority,
                                selectedCategoryIDs,
                                now
                            )
                            guard updatedTask != nil else {
                                await send(.showToast(tone: .failure, message: "Could not update task"))
                                return
                            }
                            await send(.showToast(tone: .success, message: "Task updated"))
                        } else {
                            let createdTask = try await focusRepository.createTask(
                                activeSession.id,
                                markdown,
                                priority,
                                selectedCategoryIDs,
                                now
                            )
                            guard createdTask != nil else {
                                await send(.showToast(tone: .failure, message: "Could not save task"))
                                return
                            }
                            await send(.showToast(tone: .success, message: "Task saved"))
                        }

                        let active = try? await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.settingsRefreshTapped)
                    } catch {
                        if editingTaskID != nil {
                            await send(.showToast(tone: .failure, message: "Could not update task"))
                        } else {
                            await send(.showToast(tone: .failure, message: "Could not save task"))
                        }
                    }
                }

            case .sessionAddTaskTapped:
                state.captureDraft = State.CaptureDraft(
                    selectedCategoryIDs: persistedCaptureCategoryIDs(state)
                )
                state.windowDestinations.insert(.captureWindow)
                state.captureWindowFocusRequest &+= 1
                return .none

            case let .sessionTaskEditTapped(taskID):
                guard let draft = state.taskDrafts[id: taskID] else { return .none }

                state.captureDraft.markdown = draft.markdown
                state.captureDraft.priority = draft.priority
                state.captureDraft.selectedCategoryIDs = normalizedCategoryIDs(
                    draft.categories.map(\.id),
                    categories: state.categories
                )
                state.captureDraft.editingTaskID = taskID
                state.windowDestinations.insert(.captureWindow)
                state.captureWindowFocusRequest &+= 1
                return .none

            case let .sessionRenameTapped(name):
                guard let activeSession = state.activeSession else { return .none }

                return .run { send in
                    try? await focusRepository.renameSession(activeSession.id, name)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionTaskCategoryFilterToggled(categoryID):
                if state.selectedTaskCategoryFilterIDs.contains(categoryID) {
                    state.selectedTaskCategoryFilterIDs.remove(categoryID)
                } else {
                    state.selectedTaskCategoryFilterIDs.insert(categoryID)
                }
                return .none

            case let .sessionTaskPriorityFilterToggled(priority):
                if state.selectedTaskPriorityFilters.contains(priority) {
                    state.selectedTaskPriorityFilters.remove(priority)
                } else {
                    state.selectedTaskPriorityFilters.insert(priority)
                }
                return .none

            case .sessionTaskFiltersCleared:
                state.selectedTaskCategoryFilterIDs.removeAll()
                state.selectedTaskPriorityFilters.removeAll()
                return .none

            case let .sessionTaskPriorityCycleTapped(taskID):
                guard let draft = state.taskDrafts[id: taskID] else { return .none }
                return .send(.sessionTaskPrioritySetTapped(taskID, nextPriority(after: draft.priority)))

            case let .sessionTaskPrioritySetTapped(taskID, priority):
                guard state.activeSession != nil else { return .none }
                guard let draft = state.taskDrafts[id: taskID], draft.priority != priority else { return .none }

                state.taskDrafts[id: taskID]?.priority = priority
                if state.captureDraft.editingTaskID == taskID {
                    state.captureDraft.priority = priority
                }

                return .run { send in
                    _ = try? await focusRepository.updateTask(
                        taskID,
                        draft.markdown,
                        priority,
                        draft.categories.map(\.id),
                        now
                    )
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionTaskCompletionToggled(taskID, isCompleted):
                guard state.activeSession != nil else { return .none }
                guard state.taskDrafts[id: taskID] != nil else { return .none }

                state.taskDrafts[id: taskID]?.completedAt = isCompleted ? now : nil

                return .run { send in
                    _ = try? await focusRepository.setTaskCompletion(taskID, isCompleted, now)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionTaskChecklistLineToggled(taskID, lineIndex):
                guard state.activeSession != nil else { return .none }
                guard let draft = state.taskDrafts[id: taskID] else { return .none }

                let updatedMarkdown = MarkdownEditingCore.toggleTask(
                    in: draft.markdown,
                    lineIndex: lineIndex
                )
                guard updatedMarkdown != draft.markdown else { return .none }

                state.taskDrafts[id: taskID]?.markdown = updatedMarkdown

                return .run { send in
                    _ = try? await focusRepository.updateTask(
                        taskID,
                        updatedMarkdown,
                        draft.priority,
                        draft.categories.map(\.id),
                        now
                    )
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionTaskDeleteTapped(taskID):
                guard state.activeSession != nil else { return .none }

                return .run { send in
                    do {
                        try await focusRepository.deleteTask(taskID)
                        let active = try? await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.settingsRefreshTapped)
                        await send(.showToast(tone: .success, message: "Task deleted"))
                    } catch {
                        await send(.showToast(tone: .failure, message: "Could not delete task"))
                    }
                }

            case let .endSessionConfirmTapped(name):
                guard let activeSession = state.activeSession else { return .none }

                state.endSessionDraft = nil
                state.windowDestinations.remove(.captureWindow)
                state.windowDestinations.remove(.workspaceWindow)

                return .run { send in
                    do {
                        let endedSession = try await focusRepository.endSession(
                            activeSession.id,
                            name,
                            .manual,
                            now
                        )
                        guard endedSession != nil else {
                            let active = try? await focusRepository.loadActiveSession()
                            await send(.loadActiveSessionResponse(active))
                            await send(.settingsRefreshTapped)
                            await send(.showToast(tone: .failure, message: "Could not end session"))
                            return
                        }
                        let active = try? await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.settingsRefreshTapped)
                        await send(.showToast(tone: .success, message: "Session ended"))
                    } catch {
                        let active = try? await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.settingsRefreshTapped)
                        await send(.showToast(tone: .failure, message: "Could not end session"))
                    }
                }

            case .endSessionCancelTapped:
                state.endSessionDraft = nil
                return .none

            case .autoEndSession:
                guard let activeSession = state.activeSession else { return .none }
                state.endSessionDraft = nil
                state.windowDestinations.remove(.captureWindow)
                state.windowDestinations.remove(.workspaceWindow)

                return .run { send in
                    _ = try? await focusRepository.endSession(
                        activeSession.id,
                        nil,
                        .inactivity,
                        now
                    )
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case .sessionWindowBoundaryReached:
                guard let activeSession = state.activeSession else { return .none }

                let fromPeriod = FocusDefaults.sessionPeriod(for: activeSession.startedAt)
                let toPeriod = FocusDefaults.sessionPeriod(for: now)
                guard fromPeriod != toPeriod else { return .none }
                state.endSessionDraft = nil
                state.windowDestinations.remove(.captureWindow)

                return .run { send in
                    _ = try? await focusRepository.endSession(
                        activeSession.id,
                        nil,
                        .timeWindow,
                        now
                    )
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case .settingsRefreshTapped:
                return .run { send in
                    let sessions = (try? await focusRepository.listSessions()) ?? []
                    let categories = (try? await focusRepository.listCategories()) ?? []
                    await send(.settingsDataResponse(sessions, categories))
                }

            case .settingsSaveHotkeysTapped:
                let previous = state.hotkeys

                var startShortcut = state.settings.startShortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                if startShortcut.isEmpty {
                    startShortcut = HotkeySettings.default.startShortcut
                    state.settings.startShortcut = startShortcut
                }

                var captureShortcut = state.settings.captureShortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                if captureShortcut.isEmpty {
                    captureShortcut = HotkeySettings.default.captureShortcut
                    state.settings.captureShortcut = captureShortcut
                }

                var captureNextPriorityShortcut = state.settings.captureNextPriorityShortcut
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if captureNextPriorityShortcut.isEmpty {
                    captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
                    state.settings.captureNextPriorityShortcut = captureNextPriorityShortcut
                }

                hotkeyManager.unregister(previous.startShortcut)
                hotkeyManager.unregister(previous.captureShortcut)

                let settings = HotkeySettings(
                    startShortcut: startShortcut,
                    captureShortcut: captureShortcut,
                    captureNextPriorityShortcut: captureNextPriorityShortcut
                )
                state.hotkeys = settings
                hotkeySettingsClient.save(settings)

                return .merge(
                    .send(.registerHotkeys(settings)),
                    .send(.showToast(tone: .success, message: "Hotkeys saved"))
                )

            case .settingsResetHotkeysTapped:
                let previous = state.hotkeys
                let defaults = HotkeySettings.default

                hotkeyManager.unregister(previous.startShortcut)
                hotkeyManager.unregister(previous.captureShortcut)

                state.hotkeys = defaults
                state.settings.startShortcut = defaults.startShortcut
                state.settings.captureShortcut = defaults.captureShortcut
                state.settings.captureNextPriorityShortcut = defaults.captureNextPriorityShortcut
                hotkeySettingsClient.save(defaults)

                return .merge(
                    .send(.registerHotkeys(defaults)),
                    .send(.showToast(tone: .success, message: "Hotkeys reset to defaults"))
                )

            case let .settingsAddCategoryTapped(name, colorHex):
                return .run { send in
                    do {
                        let category = try await focusRepository.addCategory(name, colorHex)
                        guard category != nil else {
                            await send(.showToast(tone: .failure, message: "Category already exists or name is invalid"))
                            return
                        }
                        await send(.settingsRefreshTapped)
                        await send(.showToast(tone: .success, message: "Category added"))
                    } catch {
                        await send(.showToast(tone: .failure, message: "Category already exists or name is invalid"))
                    }
                }

            case let .settingsRenameCategoryTapped(id, name, colorHex):
                return .run { send in
                    try? await focusRepository.renameCategory(id, name, colorHex)
                    await send(.settingsRefreshTapped)
                }

            case let .settingsDeleteCategoryTapped(id):
                return .run { send in
                    do {
                        try await focusRepository.deleteCategory(id)
                        await send(.settingsRefreshTapped)
                        let active = try? await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.showToast(tone: .success, message: "Category deleted"))
                    } catch {
                        await send(.showToast(tone: .failure, message: "Could not delete category"))
                    }
                }

            case let .settingsRenameSessionTapped(id, name):
                return .run { send in
                    try? await focusRepository.renameSession(id, name)
                    await send(.settingsRefreshTapped)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                }

            case let .settingsDeleteSessionTapped(id):
                return .run { send in
                    do {
                        try await focusRepository.deleteSession(id)
                        await send(.settingsRefreshTapped)
                        let active = try? await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.showToast(tone: .success, message: "Session deleted"))
                    } catch {
                        await send(.showToast(tone: .failure, message: "Could not delete session"))
                    }
                }

            case let .settingsExportAllTapped(directoryURL):
                let sessionIDs = state.settings.sessions
                    .filter { $0.endedAt != nil }
                    .map(\.id)
                guard !sessionIDs.isEmpty else {
                    return .send(.showToast(tone: .failure, message: "No completed sessions to export"))
                }

                return .run { send in
                    do {
                        let urls = try await markdownExportClient.export(sessionIDs, directoryURL)
                        await send(.settingsRefreshTapped)
                        await send(.showToast(tone: .success, message: "Exported \(urls.count) session file(s)."))
                    } catch {
                        await send(.showToast(tone: .failure, message: "Export failed"))
                    }
                }

            case let .settingsExportSessionTapped(sessionID, directoryURL):
                return .run { send in
                    do {
                        let urls = try await markdownExportClient.export([sessionID], directoryURL)
                        guard !urls.isEmpty else {
                            await send(.showToast(tone: .failure, message: "Export failed"))
                            return
                        }
                        await send(.settingsRefreshTapped)
                        await send(.showToast(tone: .success, message: "Session exported"))
                    } catch {
                        await send(.showToast(tone: .failure, message: "Export failed"))
                    }
                }

            case let .showToast(tone, message):
                let toast = State.Toast(
                    id: uuid(),
                    tone: tone,
                    message: message
                )
                state.toast = toast
                return .run { [toastID = toast.id] send in
                    try await clock.sleep(for: .milliseconds(2_500))
                    await send(.toastAutoDismissFired(toastID))
                }
                .cancellable(id: CancelID.toastAutoDismiss, cancelInFlight: true)

            case let .toastAutoDismissFired(toastID):
                guard state.toast?.id == toastID else { return .none }
                state.toast = nil
                return .none

            case .toastDismissTapped:
                state.toast = nil
                return .cancel(id: CancelID.toastAutoDismiss)

            case .retryBootstrapActiveSessionButtonTapped:
                state.sessionBootstrapState = .loading

                return .run { send in
                    do {
                        let activeSession = try await focusRepository.loadActiveSession()
                        await send(.bootstrapActiveSessionLoaded(activeSession))
                    } catch {
                        await send(.bootstrapActiveSessionFailed(error.localizedDescription))
                    }
                }

            case let .bootstrapActiveSessionLoaded(session):
                state.sessionBootstrapState = .loaded
                return .send(.loadActiveSessionResponse(session))

            case let .bootstrapActiveSessionFailed(message):
                state.sessionBootstrapState = .failed(message)
                state.activeSession = nil
                state.taskDrafts = []
                state.endSessionDraft = nil
                state.windowDestinations.remove(.captureWindow)
                state.selectedTaskCategoryFilterIDs.removeAll()
                state.selectedTaskPriorityFilters.removeAll()

                return .merge(
                    .cancel(id: CancelID.inactivityMonitor),
                    .cancel(id: CancelID.sessionWindowMonitor)
                )

            case let .loadActiveSessionResponse(session):
                state.activeSession = session
                syncTaskDrafts(&state)

                if let session {
                    state.captureDraft.selectedCategoryIDs = defaultCaptureCategoryIDs(
                        session: session,
                        categories: state.categories
                    )
                    ensureCategorySelections(&state)

                    return .merge(
                        .run { send in
                            while !Task.isCancelled {
                                try await Task.sleep(nanoseconds: 60_000_000_000)
                                await send(.inactivityTick)
                            }
                        }
                        .cancellable(id: CancelID.inactivityMonitor, cancelInFlight: true),
                        .run { [sessionStartedAt = session.startedAt] send in
                            let startedPeriod = FocusDefaults.sessionPeriod(for: sessionStartedAt)
                            let currentPeriod = FocusDefaults.sessionPeriod(for: now)
                            if currentPeriod != startedPeriod {
                                await send(.sessionWindowBoundaryReached)
                                return
                            }

                            while !Task.isCancelled {
                                let currentTime = now
                                let nextBoundary = FocusDefaults.nextSessionBoundary(after: currentTime)
                                let seconds = max(nextBoundary.timeIntervalSince(currentTime), 0)
                                try await clock.sleep(for: .seconds(seconds))
                                await send(.sessionWindowBoundaryReached)
                                return
                            }
                        }
                        .cancellable(id: CancelID.sessionWindowMonitor, cancelInFlight: true)
                    )
                }

                state.endSessionDraft = nil
                state.windowDestinations.remove(.captureWindow)
                state.captureDraft = State.CaptureDraft(
                    selectedCategoryIDs: []
                )
                state.selectedTaskCategoryFilterIDs.removeAll()
                state.selectedTaskPriorityFilters.removeAll()

                return .merge(
                    .cancel(id: CancelID.inactivityMonitor),
                    .cancel(id: CancelID.sessionWindowMonitor)
                )

            case let .loadCategoriesResponse(categories):
                state.categories = categories.sorted(by: {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                })
                state.settings.categories = state.categories
                if let activeSession = state.activeSession, state.captureDraft.editingTaskID == nil {
                    state.captureDraft.selectedCategoryIDs = defaultCaptureCategoryIDs(
                        session: activeSession,
                        categories: state.categories
                    )
                }
                ensureCategorySelections(&state)
                return .none

            case let .settingsDataResponse(sessions, categories):
                let sortedCategories = categories.sorted(by: {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                })
                state.settings.sessions = sessions
                state.settings.categories = sortedCategories
                state.categories = sortedCategories
                if let activeSession = state.activeSession, state.captureDraft.editingTaskID == nil {
                    state.captureDraft.selectedCategoryIDs = defaultCaptureCategoryIDs(
                        session: activeSession,
                        categories: state.categories
                    )
                }
                ensureCategorySelections(&state)
                return .none
            }
        }
    }
}

private func syncTaskDrafts(_ state: inout AppFeature.State) {
    guard let activeSession = state.activeSession else {
        state.taskDrafts = []
        return
    }

    state.taskDrafts = IdentifiedArray(
        uniqueElements: activeSession.tasks
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map {
                AppFeature.State.TaskDraft(
                    id: $0.id,
                    categories: $0.categories,
                    markdown: $0.markdown,
                    priority: $0.priority,
                    completedAt: $0.completedAt,
                    carriedFromTaskID: $0.carriedFromTaskID,
                    carriedFromSessionName: $0.carriedFromSessionName,
                    createdAt: $0.createdAt
                )
            }
    )
}

private func defaultCaptureCategoryIDs(
    session: FocusSessionRecord,
    categories: [SessionCategoryRecord]
) -> [UUID] {
    guard
        let latestCategoryIDs = session.tasks
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first?
            .categories
            .map(\.id)
    else {
        return []
    }

    return normalizedCategoryIDs(latestCategoryIDs, categories: categories)
}

private func normalizedCategoryIDs(_ categoryIDs: [UUID], categories: [SessionCategoryRecord]) -> [UUID] {
    var seen = Set<UUID>()
    var normalized: [UUID] = []

    for categoryID in categoryIDs {
        guard !seen.contains(categoryID) else { continue }
        guard categories.contains(where: { $0.id == categoryID }) else { continue }
        seen.insert(categoryID)
        normalized.append(categoryID)
    }

    return normalized
}

private func persistedCaptureCategoryIDs(_ state: AppFeature.State) -> [UUID] {
    normalizedCategoryIDs(
        state.captureDraft.selectedCategoryIDs,
        categories: state.categories
    )
}

private func ensureCategorySelections(_ state: inout AppFeature.State) {
    state.captureDraft.selectedCategoryIDs = normalizedCategoryIDs(
        state.captureDraft.selectedCategoryIDs,
        categories: state.categories
    )

    let validFilteredCategoryIDs = Set(state.categories.map(\.id))
    state.selectedTaskCategoryFilterIDs = state.selectedTaskCategoryFilterIDs.intersection(validFilteredCategoryIDs)
}

private func nextPriority(after priority: NotePriority) -> NotePriority {
    let priorities = NotePriority.allCases
    guard let currentIndex = priorities.firstIndex(of: priority) else {
        return .none
    }

    let nextIndex = priorities.index(after: currentIndex)
    if nextIndex == priorities.endIndex {
        return priorities[priorities.startIndex]
    }

    return priorities[nextIndex]
}
