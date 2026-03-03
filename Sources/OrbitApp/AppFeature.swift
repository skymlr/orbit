import CasePaths
import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    private enum CancelID {
        case inactivityMonitor
        case hotkeyRegistration
    }

    @CasePathable
    enum WindowDestination: Hashable, Sendable {
        case workspaceWindow
        case captureWindow
        case endSessionWindow
    }

    @ObservableState
    struct State: Equatable {
        enum TaskCategoryFilter: Equatable {
            case all
            case category(UUID)
        }

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

        struct SettingsState: Equatable {
            var sessions: [FocusSessionRecord] = []
            var categories: [SessionCategoryRecord] = []
            var startShortcut = HotkeySettings.default.startShortcut
            var captureShortcut = HotkeySettings.default.captureShortcut
            var captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
            var statusMessage: String?
        }

        var activeSession: FocusSessionRecord?
        var taskDrafts: IdentifiedArrayOf<TaskDraft> = []

        var categories: [SessionCategoryRecord] = []
        var hotkeys: HotkeySettings = .default

        var captureDraft = CaptureDraft()
        var endSessionDraft: EndSessionDraft?

        var selectedTaskCategoryFilter: TaskCategoryFilter = .all

        var settings = SettingsState()

        var windowDestinations: Set<WindowDestination> = []
        var workspaceWindowFocusRequest = 0
        var sessionBootstrapState: SessionBootstrapState = .idle
        var hasLaunched = false

        var filteredTaskDrafts: [TaskDraft] {
            switch selectedTaskCategoryFilter {
            case .all:
                return Array(taskDrafts)
            case let .category(categoryID):
                return taskDrafts.filter { $0.categories.contains(where: { $0.id == categoryID }) }
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
        case workspaceWindowEndSessionTapped

        case workspaceWindowClosed
        case captureWindowClosed
        case endSessionWindowClosed

        case captureSubmitTapped
        case sessionAddTaskTapped
        case sessionRenameTapped(String)
        case sessionTaskCategoryFilterChangedTapped(State.TaskCategoryFilter)
        case sessionTaskDeleteTapped(UUID)
        case sessionTaskEditTapped(UUID)
        case sessionTaskCompletionToggled(UUID, Bool)

        case endSessionConfirmTapped(name: String)
        case endSessionCancelTapped
        case autoEndSession

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
        case settingsExportCompleted(Int)
        case operationFailed(String)
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
                return .merge(
                    .cancel(id: CancelID.inactivityMonitor),
                    .cancel(id: CancelID.hotkeyRegistration)
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
                        await send(.loadActiveSessionResponse(active))
                        await send(.openWorkspaceTapped)
                        await send(.settingsRefreshTapped)
                        if active == nil {
                            await send(.operationFailed("Failed to load the newly started session."))
                        }
                    } catch {
                        await send(.operationFailed("Failed to start session: \(error.localizedDescription)"))
                    }
                }

            case .captureTapped:
                if state.activeSession != nil {
                    state.windowDestinations.insert(.captureWindow)
                    return .none
                }
                state.windowDestinations.insert(.workspaceWindow)
                state.windowDestinations.insert(.captureWindow)

                return .run { send in
                    do {
                        _ = try await focusRepository.startSession(now)
                        let active = try await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.openWorkspaceTapped)
                        await send(.captureTapped)
                        await send(.settingsRefreshTapped)
                        if active == nil {
                            await send(.operationFailed("Failed to load the newly started session."))
                        }
                    } catch {
                        await send(.operationFailed("Failed to start capture session: \(error.localizedDescription)"))
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
                return .none

            case .workspaceWindowEndSessionTapped:
                guard let active = state.activeSession else { return .none }
                state.endSessionDraft = State.EndSessionDraft(
                    id: uuid(),
                    name: active.name
                )
                state.windowDestinations.remove(.captureWindow)
                state.windowDestinations.remove(.workspaceWindow)
                state.windowDestinations.insert(.endSessionWindow)
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

            case .endSessionWindowClosed:
                state.windowDestinations.remove(.endSessionWindow)
                state.endSessionDraft = nil
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
                    if let taskID = editingTaskID {
                        _ = try? await focusRepository.updateTask(taskID, markdown, priority, selectedCategoryIDs, now)
                    } else {
                        _ = try? await focusRepository.createTask(activeSession.id, markdown, priority, selectedCategoryIDs, now)
                    }
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case .sessionAddTaskTapped:
                state.captureDraft = State.CaptureDraft(
                    selectedCategoryIDs: persistedCaptureCategoryIDs(state)
                )
                state.windowDestinations.insert(.captureWindow)
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
                return .none

            case let .sessionRenameTapped(name):
                guard let activeSession = state.activeSession else { return .none }

                return .run { send in
                    try? await focusRepository.renameSession(activeSession.id, name)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionTaskCategoryFilterChangedTapped(filter):
                state.selectedTaskCategoryFilter = filter
                return .none

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

            case let .sessionTaskDeleteTapped(taskID):
                guard state.activeSession != nil else { return .none }

                return .run { send in
                    try? await focusRepository.deleteTask(taskID)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .endSessionConfirmTapped(name):
                guard let activeSession = state.activeSession else { return .none }

                state.endSessionDraft = nil
                state.windowDestinations.remove(.endSessionWindow)
                state.windowDestinations.remove(.captureWindow)
                state.windowDestinations.remove(.workspaceWindow)

                return .run { send in
                    _ = try? await focusRepository.endSession(
                        activeSession.id,
                        name,
                        .manual,
                        now
                    )
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case .endSessionCancelTapped:
                state.endSessionDraft = nil
                state.windowDestinations.remove(.endSessionWindow)
                return .none

            case .autoEndSession:
                guard let activeSession = state.activeSession else { return .none }
                state.endSessionDraft = nil
                state.windowDestinations.remove(.endSessionWindow)
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
                state.settings.statusMessage = "Hotkeys saved"

                return .send(.registerHotkeys(settings))

            case .settingsResetHotkeysTapped:
                let previous = state.hotkeys
                let defaults = HotkeySettings.default

                hotkeyManager.unregister(previous.startShortcut)
                hotkeyManager.unregister(previous.captureShortcut)

                state.hotkeys = defaults
                state.settings.startShortcut = defaults.startShortcut
                state.settings.captureShortcut = defaults.captureShortcut
                state.settings.captureNextPriorityShortcut = defaults.captureNextPriorityShortcut
                state.settings.statusMessage = "Hotkeys reset to defaults"
                hotkeySettingsClient.save(defaults)

                return .send(.registerHotkeys(defaults))

            case let .settingsAddCategoryTapped(name, colorHex):
                return .run { send in
                    _ = try? await focusRepository.addCategory(name, colorHex)
                    await send(.settingsRefreshTapped)
                }

            case let .settingsRenameCategoryTapped(id, name, colorHex):
                return .run { send in
                    try? await focusRepository.renameCategory(id, name, colorHex)
                    await send(.settingsRefreshTapped)
                }

            case let .settingsDeleteCategoryTapped(id):
                return .run { send in
                    try? await focusRepository.deleteCategory(id)
                    await send(.settingsRefreshTapped)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
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
                    try? await focusRepository.deleteSession(id)
                    await send(.settingsRefreshTapped)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                }

            case let .settingsExportAllTapped(directoryURL):
                let sessionIDs = state.settings.sessions
                    .filter { $0.endedAt != nil }
                    .map(\.id)
                guard !sessionIDs.isEmpty else {
                    state.settings.statusMessage = "No sessions available to export."
                    return .none
                }

                return .run { send in
                    let urls = (try? await markdownExportClient.export(sessionIDs, directoryURL)) ?? []
                    await send(.settingsExportCompleted(urls.count))
                    await send(.settingsRefreshTapped)
                }

            case let .settingsExportSessionTapped(sessionID, directoryURL):
                return .run { send in
                    let urls = (try? await markdownExportClient.export([sessionID], directoryURL)) ?? []
                    await send(.settingsExportCompleted(urls.count))
                    await send(.settingsRefreshTapped)
                }

            case let .settingsExportCompleted(count):
                state.settings.statusMessage = "Exported \(count) session markdown file(s)."
                return .none

            case let .operationFailed(message):
                state.settings.statusMessage = message
                return .none

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
                state.windowDestinations.remove(.endSessionWindow)
                state.selectedTaskCategoryFilter = .all

                return .cancel(id: CancelID.inactivityMonitor)

            case let .loadActiveSessionResponse(session):
                state.activeSession = session
                syncTaskDrafts(&state)

                if let session {
                    state.captureDraft.selectedCategoryIDs = defaultCaptureCategoryIDs(
                        session: session,
                        categories: state.categories
                    )
                    ensureCategorySelections(&state)

                    return .run { send in
                        while !Task.isCancelled {
                            try await Task.sleep(nanoseconds: 60_000_000_000)
                            await send(.inactivityTick)
                        }
                    }
                    .cancellable(id: CancelID.inactivityMonitor, cancelInFlight: true)
                }

                state.endSessionDraft = nil
                state.windowDestinations.remove(.endSessionWindow)
                state.windowDestinations.remove(.captureWindow)
                state.captureDraft = State.CaptureDraft(
                    selectedCategoryIDs: []
                )
                state.selectedTaskCategoryFilter = .all

                return .cancel(id: CancelID.inactivityMonitor)

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

    switch state.selectedTaskCategoryFilter {
    case .all:
        break
    case let .category(categoryID):
        if !state.categories.contains(where: { $0.id == categoryID })
            || !state.taskDrafts.contains(where: { draft in
                draft.categories.contains(where: { $0.id == categoryID })
            })
        {
            state.selectedTaskCategoryFilter = .all
        }
    }
}
