import ComposableArchitecture
import Foundation

extension AppFeature {
    func reduceLifecycle(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding,
                .autoEndSession,
                .captureSubmitTapped,
                .captureTapped,
                .endSessionCancelTapped,
                .endSessionConfirmTapped,
                .endSessionTapped,
                .openWorkspaceTapped,
                .sessionAddTaskTapped,
                .sessionRenameTapped,
                .sessionTaskCategoryFilterToggled,
                .sessionTaskChecklistLineToggled,
                .sessionTaskCompletionToggled,
                .sessionTaskDeleteTapped,
                .sessionTaskEditTapped,
                .sessionTaskFiltersCleared,
                .sessionTaskPriorityCycleTapped,
                .sessionTaskPriorityFilterToggled,
                .sessionTaskPrioritySetTapped,
                .sessionWindowBoundaryReached,
                .settingsAddCategoryTapped,
                .settingsDeleteCategoryTapped,
                .settingsDeleteSessionTapped,
                .settingsExportAllTapped,
                .settingsExportSessionTapped,
                .settingsRefreshTapped,
                .settingsRenameCategoryTapped,
                .settingsRenameSessionTapped,
                .settingsResetHotkeysTapped,
                .settingsSaveHotkeysTapped,
                .showToast,
                .startSessionTapped,
                .toastAutoDismissFired,
                .toastDismissTapped:
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

        case .workspaceWindowClosed:
            state.windowDestinations.remove(.workspaceWindow)
            return .none

        case .captureWindowClosed:
            state.windowDestinations.remove(.captureWindow)
            state.captureDraft = State.CaptureDraft(
                selectedCategoryIDs: persistedCaptureCategoryIDs(state)
            )
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
                            try await continuousClock.sleep(for: .seconds(seconds))
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
