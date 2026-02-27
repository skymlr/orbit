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
        case sessionWindow
        case captureWindow
        case endSessionWindow
    }

    @ObservableState
    struct State: Equatable {
        struct CaptureDraft: Equatable {
            var text = ""
            var tags = ""
            var priority: NotePriority = .none
            var editingNoteID: UUID?
        }

        struct EndSessionDraft: Equatable, Identifiable {
            var id = UUID()
            var name = ""
            var selectedCategoryID = FocusDefaults.focusCategoryID
            var categories: [SessionCategoryRecord] = []
        }

        struct NoteDraft: Equatable, Identifiable {
            var id: UUID
            var text: String
            var tags: [String]
            var priority: NotePriority
            var createdAt: Date
        }

        struct SettingsState: Equatable {
            var sessions: [FocusSessionRecord] = []
            var categories: [SessionCategoryRecord] = []
            var startShortcut = HotkeySettings.default.startShortcut
            var captureShortcut = HotkeySettings.default.captureShortcut
            var statusMessage: String?
        }

        var activeSession: FocusSessionRecord?
        var noteDrafts: IdentifiedArrayOf<NoteDraft> = []

        var categories: [SessionCategoryRecord] = []
        var hotkeys: HotkeySettings = .default

        var captureDraft = CaptureDraft()
        var endSessionDraft: EndSessionDraft?

        var settings = SettingsState()

        var windowDestinations: Set<WindowDestination> = []
        var sessionWindowFocusRequest = 0
        var hasLaunched = false
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
        case openSessionTapped
        case endSessionTapped
        case sessionWindowEndSessionTapped

        case sessionWindowClosed
        case captureWindowClosed
        case endSessionWindowClosed

        case captureSubmitTapped
        case sessionAddNoteTapped
        case sessionNoteEditTapped(UUID)
        case sessionRenameTapped(String)
        case sessionCategoryChangedTapped(UUID)
        case sessionNoteSaveTapped(UUID, String, [String], NotePriority)
        case sessionNoteTaskToggleTapped(UUID, Int)
        case sessionNoteDeleteTapped(UUID)

        case endSessionConfirmTapped(name: String, categoryID: UUID?)
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

                let hotkeys = hotkeySettingsClient.load()
                state.hotkeys = hotkeys
                state.settings.startShortcut = hotkeys.startShortcut
                state.settings.captureShortcut = hotkeys.captureShortcut

                return .merge(
                    .send(.registerHotkeys(hotkeys)),
                    .run { send in
                        let active = try? await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
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
                    nil,
                    .appClosed,
                    now
                )
                state.activeSession = nil
                state.noteDrafts = []
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
                    return .send(.openSessionTapped)
                }
                state.windowDestinations.insert(.sessionWindow)

                return .run { send in
                    do {
                        _ = try await focusRepository.startSession(now)
                        let active = try await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.openSessionTapped)
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
                state.windowDestinations.insert(.sessionWindow)
                state.windowDestinations.insert(.captureWindow)

                return .run { send in
                    do {
                        _ = try await focusRepository.startSession(now)
                        let active = try await focusRepository.loadActiveSession()
                        await send(.loadActiveSessionResponse(active))
                        await send(.openSessionTapped)
                        await send(.captureTapped)
                        await send(.settingsRefreshTapped)
                        if active == nil {
                            await send(.operationFailed("Failed to load the newly started session."))
                        }
                    } catch {
                        await send(.operationFailed("Failed to start capture session: \(error.localizedDescription)"))
                    }
                }

            case .openSessionTapped:
                guard state.activeSession != nil else { return .none }
                state.windowDestinations.insert(.sessionWindow)
                state.sessionWindowFocusRequest &+= 1
                return .none

            case .endSessionTapped:
                guard let active = state.activeSession else { return .none }
                state.endSessionDraft = State.EndSessionDraft(
                    id: uuid(),
                    name: active.name,
                    selectedCategoryID: active.categoryID,
                    categories: state.categories
                )
                return .none

            case .sessionWindowEndSessionTapped:
                guard let active = state.activeSession else { return .none }
                state.endSessionDraft = State.EndSessionDraft(
                    id: uuid(),
                    name: active.name,
                    selectedCategoryID: active.categoryID,
                    categories: state.categories
                )
                state.windowDestinations.remove(.captureWindow)
                state.windowDestinations.remove(.sessionWindow)
                state.windowDestinations.insert(.endSessionWindow)
                return .none

            case .sessionWindowClosed:
                state.windowDestinations.remove(.sessionWindow)
                return .none

            case .captureWindowClosed:
                state.windowDestinations.remove(.captureWindow)
                state.captureDraft = State.CaptureDraft()
                return .none

            case .endSessionWindowClosed:
                state.windowDestinations.remove(.endSessionWindow)
                state.endSessionDraft = nil
                return .none

            case .captureSubmitTapped:
                guard let activeSession = state.activeSession else { return .none }
                let text = state.captureDraft.text
                let tags = FocusDefaults.parseTagInput(state.captureDraft.tags)
                let priority = state.captureDraft.priority
                let editingNoteID = state.captureDraft.editingNoteID

                state.captureDraft = State.CaptureDraft()
                state.windowDestinations.remove(.captureWindow)

                return .run { send in
                    if let noteID = editingNoteID {
                        _ = try? await focusRepository.updateNote(noteID, text, priority, tags, now)
                    } else {
                        _ = try? await focusRepository.createNote(activeSession.id, text, priority, tags, now)
                    }
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case .sessionAddNoteTapped:
                state.captureDraft = State.CaptureDraft()
                state.windowDestinations.insert(.captureWindow)
                return .none

            case let .sessionNoteEditTapped(noteID):
                guard let draft = state.noteDrafts[id: noteID] else { return .none }

                state.captureDraft.text = draft.text
                state.captureDraft.tags = draft.tags.joined(separator: ", ")
                state.captureDraft.priority = draft.priority
                state.captureDraft.editingNoteID = noteID
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

            case let .sessionCategoryChangedTapped(categoryID):
                guard let activeSession = state.activeSession else { return .none }

                return .run { send in
                    try? await focusRepository.updateSessionCategory(activeSession.id, categoryID)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionNoteSaveTapped(noteID, text, tags, priority):
                guard state.activeSession != nil else { return .none }

                return .run { send in
                    _ = try? await focusRepository.updateNote(noteID, text, priority, tags, now)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionNoteTaskToggleTapped(noteID, lineIndex):
                guard state.activeSession != nil else { return .none }
                guard let draft = state.noteDrafts[id: noteID] else { return .none }

                let toggledText = MarkdownEditingCore.toggleTask(in: draft.text, lineIndex: lineIndex)
                guard toggledText != draft.text else { return .none }

                state.noteDrafts[id: noteID]?.text = toggledText

                return .run { send in
                    _ = try? await focusRepository.updateNote(noteID, toggledText, draft.priority, draft.tags, now)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .sessionNoteDeleteTapped(noteID):
                guard state.activeSession != nil else { return .none }

                return .run { send in
                    try? await focusRepository.deleteNote(noteID)
                    let active = try? await focusRepository.loadActiveSession()
                    await send(.loadActiveSessionResponse(active))
                    await send(.settingsRefreshTapped)
                }

            case let .endSessionConfirmTapped(name, categoryID):
                guard let activeSession = state.activeSession else { return .none }

                state.endSessionDraft = nil
                state.windowDestinations.remove(.endSessionWindow)
                state.windowDestinations.remove(.captureWindow)
                state.windowDestinations.remove(.sessionWindow)

                return .run { send in
                    _ = try? await focusRepository.endSession(
                        activeSession.id,
                        name,
                        categoryID,
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
                state.windowDestinations.remove(.sessionWindow)

                return .run { send in
                    _ = try? await focusRepository.endSession(
                        activeSession.id,
                        nil,
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

                hotkeyManager.unregister(previous.startShortcut)
                hotkeyManager.unregister(previous.captureShortcut)

                let settings = HotkeySettings(startShortcut: startShortcut, captureShortcut: captureShortcut)
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

            case let .loadActiveSessionResponse(session):
                state.activeSession = session
                syncNoteDrafts(&state)

                if let session {
                    if var endSessionDraft = state.endSessionDraft {
                        endSessionDraft.name = session.name
                        if state.categories.contains(where: { $0.id == session.categoryID }) {
                            endSessionDraft.selectedCategoryID = session.categoryID
                        }
                        state.endSessionDraft = endSessionDraft
                    }

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
                state.windowDestinations.remove(.sessionWindow)

                return .cancel(id: CancelID.inactivityMonitor)

            case let .loadCategoriesResponse(categories):
                state.categories = categories.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
                state.settings.categories = state.categories

                if var endSessionDraft = state.endSessionDraft {
                    endSessionDraft.categories = state.categories
                    if !state.categories.contains(where: { $0.id == endSessionDraft.selectedCategoryID }) {
                        endSessionDraft.selectedCategoryID = FocusDefaults.focusCategoryID
                    }
                    state.endSessionDraft = endSessionDraft
                }

                return .none

            case let .settingsDataResponse(sessions, categories):
                state.settings.sessions = sessions
                state.settings.categories = categories
                state.categories = categories
                return .none
            }
        }
    }
}

private func syncNoteDrafts(_ state: inout AppFeature.State) {
    guard let activeSession = state.activeSession else {
        state.noteDrafts = []
        return
    }

    state.noteDrafts = IdentifiedArray(
        uniqueElements: activeSession.notes
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map {
                AppFeature.State.NoteDraft(
                    id: $0.id,
                    text: $0.text,
                    tags: $0.tags,
                    priority: $0.priority,
                    createdAt: $0.createdAt
                )
            }
    )
}
