import ComposableArchitecture
import Foundation

extension AppFeature {
    func reduceLifecycle(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding,
                .autoEndSession,
                .captureDeleteTapped,
                .captureSubmitTapped,
                .captureTapped,
                .endSessionCancelTapped,
                .endSessionConfirmTapped,
                .endSessionTapped,
                .openWorkspaceTapped,
                .openPreferencesTapped,
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
                .settingsCloudSyncRetryTapped,
                .settingsCloudSyncToggled,
                .settingsAddCategoryTapped,
                .settingsDeleteCategoryTapped,
                .settingsDeleteSessionTapped,
                .exportDirectorySelected,
                .exportDirectorySelectionCancelled,
                .exportAllButtonTapped,
                .exportSessionButtonTapped,
                .settingsRefreshTapped,
                .settingsResetAppearanceTapped,
                .settingsRenameCategoryTapped,
                .settingsRenameSessionTapped,
                .settingsResetHotkeysTapped,
                .settingsSaveAppearanceTapped,
                .settingsSaveHotkeysTapped,
                .sharedExportDismissed,
                .sharedExportFailed,
                .sharedExportPrepared,
                .showToast,
                .startSessionTapped,
                .toastAutoDismissFired,
                .toastDismissTapped:
            return .none

        case .onLaunch:
            guard !state.hasLaunched else { return .none }
            state.hasLaunched = true
            state.sessionBootstrapState = .loading
            state.platform = State.PlatformFeatures(platformCapabilities)
            state.settings.showsHotkeySettings = state.platform.supportsGlobalHotkeys

            let hotkeys = hotkeySettingsClient.load()
            state.hotkeys = hotkeys
            state.settings.startShortcut = hotkeys.startShortcut
            state.settings.captureShortcut = hotkeys.captureShortcut
            state.settings.captureNextPriorityShortcut = hotkeys.captureNextPriorityShortcut

            let appearance = appearanceSettingsClient.load()
            state.appearance = appearance
            state.settings.appearanceDraft = appearance
            state.isCloudSyncEnabled = state.platform.supportsCloudSync
                ? cloudSyncSettingsClient.load()
                : false
            state.syncStatus = state.isCloudSyncEnabled ? .starting : .off

            var effects: [Effect<Action>] = []

            if state.platform.supportsCloudSync {
                effects.append(monitorCloudSyncEffect())
            }

            if state.platform.supportsGlobalHotkeys {
                effects.insert(.send(.registerHotkeys(hotkeys)), at: 0)
            }

            if state.isCloudSyncEnabled {
                effects.append(startCloudSyncEffect())
            } else {
                effects.append(contentsOf: launchDataLoadEffects())
            }

            return .merge(effects)

        case .appWillTerminate:
            if let activeSession = state.activeSession {
                try? focusRepository.endSessionSync(
                    activeSession.id,
                    nil,
                    .appClosed,
                    now
                )
            }
            state.activeSession = nil
            state.taskDrafts = []
            state.presentation = State.PresentationState()
            state.endSessionDraft = nil
            state.toast = nil
            return .merge(
                .cancel(id: CancelID.cloudSyncMonitor),
                .cancel(id: CancelID.cloudSyncOperation),
                .cancel(id: CancelID.inactivityMonitor),
                .cancel(id: CancelID.sessionWindowMonitor),
                .cancel(id: CancelID.hotkeyRegistration),
                .cancel(id: CancelID.toastAutoDismiss)
            )

        case .inactivityTick:
            guard state.platform.supportsIdleMonitoring else { return .none }
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
            guard state.platform.supportsGlobalHotkeys else { return .none }
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
            state.presentation.isWorkspacePresented = false
            return .none

        case .captureWindowClosed:
            state.presentation.isCapturePresented = false
            state.captureDraft = State.CaptureDraft(
                selectedCategoryIDs: persistedCaptureCategoryIDs(state)
            )
            return .none

        case .preferencesWindowClosed:
            state.presentation.isPreferencesPresented = false
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
            state.presentation.isCapturePresented = false
            state.presentation.isPreferencesPresented = false
            state.selectedTaskCategoryFilterIDs.removeAll()
            state.selectedTaskPriorityFilters.removeAll()

            return .merge(
                .cancel(id: CancelID.cloudSyncOperation),
                .cancel(id: CancelID.inactivityMonitor),
                .cancel(id: CancelID.sessionWindowMonitor)
            )

        case let .cloudSyncMonitorUpdated(isEnabled, engineState):
            state.isCloudSyncEnabled = isEnabled
            state.syncStatus = syncStatus(
                isEnabled: isEnabled,
                engineState: engineState,
                currentStatus: state.syncStatus
            )
            return .none

        case .cloudSyncStartSucceeded:
            state.syncStatus = .enabled
            return .merge(launchDataLoadEffects())

        case let .cloudSyncStartFailed(message):
            state.syncStatus = state.isCloudSyncEnabled ? .retryNeeded(message) : .off
            var effects = launchDataLoadEffects()
            effects.append(.send(.showToast(tone: .failure, message: message)))
            return .merge(effects)

        case .cloudSyncFetchSucceeded:
            state.syncStatus = .enabled
            return .merge(launchDataLoadEffects())

        case let .cloudSyncFetchFailed(message):
            state.syncStatus = .retryNeeded(message)
            return .send(.showToast(tone: .failure, message: message))

        case let .loadActiveSessionResponse(session):
            state.activeSession = session
            syncTaskDrafts(&state)

            if let session {
                state.captureDraft.selectedCategoryIDs = defaultCaptureCategoryIDs(
                    session: session,
                    categories: state.categories
                )
                ensureCategorySelections(&state)

                var effects: [Effect<Action>] = []

                if state.platform.supportsIdleMonitoring {
                    effects.append(
                        .run { send in
                            while !Task.isCancelled {
                                try await Task.sleep(nanoseconds: 60_000_000_000)
                                await send(.inactivityTick)
                            }
                        }
                        .cancellable(id: CancelID.inactivityMonitor, cancelInFlight: true)
                    )
                }

                effects.append(
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

                return .merge(effects)
            }

            state.endSessionDraft = nil
            state.presentation.isCapturePresented = false
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

    func launchDataLoadEffects() -> [Effect<Action>] {
        [
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
        ]
    }

    func monitorCloudSyncEffect() -> Effect<Action> {
        .run { send in
            while !Task.isCancelled {
                try await continuousClock.sleep(for: .seconds(2))
                await send(
                    .cloudSyncMonitorUpdated(
                        cloudSyncSettingsClient.load(),
                        cloudSyncClient.state()
                    )
                )
            }
        }
        .cancellable(id: CancelID.cloudSyncMonitor, cancelInFlight: true)
    }

    func startCloudSyncEffect() -> Effect<Action> {
        .run { send in
            do {
                try await cloudSyncClient.start()
                try await focusRepository.reconcileSyncInvariants()
                await send(.cloudSyncStartSucceeded)
            } catch {
                await send(
                    .cloudSyncStartFailed(
                        cloudSyncFailureMessage(
                            prefix: "Could not start iCloud sync",
                            error: error
                        )
                    )
                )
            }
        }
        .cancellable(id: CancelID.cloudSyncOperation, cancelInFlight: true)
    }

    func fetchCloudSyncEffect() -> Effect<Action> {
        .run { send in
            do {
                try await cloudSyncClient.fetchChanges()
                try await focusRepository.reconcileSyncInvariants()
                await send(.cloudSyncFetchSucceeded)
            } catch {
                await send(
                    .cloudSyncFetchFailed(
                        cloudSyncFailureMessage(
                            prefix: "Could not refresh iCloud sync",
                            error: error
                        )
                    )
                )
            }
        }
        .cancellable(id: CancelID.cloudSyncOperation, cancelInFlight: true)
    }

    func syncStatus(
        isEnabled: Bool,
        engineState: CloudSyncEngineState,
        currentStatus: SyncStatus
    ) -> SyncStatus {
        guard isEnabled else {
            return .off
        }

        if engineState.isSynchronizing {
            return .syncing
        }

        if engineState.isRunning {
            return .enabled
        }

        switch currentStatus {
        case .starting:
            return .starting
        case .syncing:
            return .syncing
        default:
            return .retryNeeded("iCloud sync is paused or unavailable.")
        }
    }

    func cloudSyncFailureMessage(prefix: String, error: any Error) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            return prefix
        }
        return "\(prefix). \(description)"
    }
}
