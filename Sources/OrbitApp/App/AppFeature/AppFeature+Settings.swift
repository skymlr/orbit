import ComposableArchitecture
import Foundation

extension AppFeature {
    func reduceSettings(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding,
                .appWillTerminate,
                .autoEndSession,
                .bootstrapActiveSessionFailed,
                .bootstrapActiveSessionLoaded,
                .captureSubmitTapped,
                .captureTapped,
                .captureWindowClosed,
                .endSessionCancelTapped,
                .endSessionConfirmTapped,
                .endSessionTapped,
                .hotkeyTriggered,
                .inactivityTick,
                .loadActiveSessionResponse,
                .loadCategoriesResponse,
                .onLaunch,
                .openWorkspaceTapped,
                .registerHotkeys,
                .retryBootstrapActiveSessionButtonTapped,
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
                .startSessionTapped,
                .workspaceWindowClosed:
            return .none

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
                try await continuousClock.sleep(for: .milliseconds(2_500))
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

        case .settingsDataResponse:
            return .none
        }
    }
}
