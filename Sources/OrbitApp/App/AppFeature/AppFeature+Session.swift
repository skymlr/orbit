import ComposableArchitecture
import Foundation

extension AppFeature {
    func reduceSession(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding,
                .appWillTerminate,
                .bootstrapActiveSessionFailed,
                .bootstrapActiveSessionLoaded,
                .captureWindowClosed,
                .exportDirectorySelectionCancelled,
                .exportDirectorySelected,
                .exportAllButtonTapped,
                .exportSessionButtonTapped,
                .hotkeyTriggered,
                .inactivityTick,
                .loadActiveSessionResponse,
                .loadCategoriesResponse,
                .onLaunch,
                .preferencesWindowClosed,
                .registerHotkeys,
                .retryBootstrapActiveSessionButtonTapped,
                .settingsAddCategoryTapped,
                .settingsDeleteCategoryTapped,
                .settingsDeleteSessionTapped,
                .settingsDataResponse,
                .settingsRefreshTapped,
                .settingsRenameCategoryTapped,
                .settingsRenameSessionTapped,
                .settingsResetAppearanceTapped,
                .settingsResetHotkeysTapped,
                .settingsSaveAppearanceTapped,
                .settingsSaveHotkeysTapped,
                .sharedExportDismissed,
                .sharedExportFailed,
                .sharedExportPrepared,
                .showToast,
                .toastAutoDismissFired,
                .toastDismissTapped,
                .workspaceWindowClosed:
            return .none

        case .startSessionTapped:
            if state.activeSession != nil {
                return .send(.openWorkspaceTapped)
            }
            state.presentation.isWorkspacePresented = true

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
                state.presentation.isCapturePresented = true
                state.presentation.capturePresentationRequest &+= 1
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
            state.presentation.isWorkspacePresented = true
            state.presentation.workspacePresentationRequest &+= 1
            return .none

        case .openPreferencesTapped:
            state.presentation.isPreferencesPresented = true
            state.presentation.preferencesPresentationRequest &+= 1
            return .none

        case .endSessionTapped:
            guard let active = state.activeSession else { return .none }
            state.endSessionDraft = State.EndSessionDraft(
                id: uuid(),
                name: active.name
            )
            state.presentation.isCapturePresented = false
            if !state.presentation.isWorkspacePresented {
                state.presentation.isWorkspacePresented = true
                state.presentation.workspacePresentationRequest &+= 1
            }
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
            state.presentation.isCapturePresented = false

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
            state.presentation.isCapturePresented = true
            state.presentation.capturePresentationRequest &+= 1
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
            state.presentation.isCapturePresented = true
            state.presentation.capturePresentationRequest &+= 1
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
            state.presentation.isCapturePresented = false
            state.presentation.isWorkspacePresented = false

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
            state.presentation.isCapturePresented = false
            state.presentation.isWorkspacePresented = false

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
            state.presentation.isCapturePresented = false

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
        }
    }

    func syncTaskDrafts(_ state: inout State) {
        guard let activeSession = state.activeSession else {
            state.taskDrafts = []
            return
        }

        state.taskDrafts = IdentifiedArray(
            uniqueElements: activeSession.tasks
                .sorted(by: { $0.createdAt > $1.createdAt })
                .map {
                    State.TaskDraft(
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

    func defaultCaptureCategoryIDs(
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

    func normalizedCategoryIDs(_ categoryIDs: [UUID], categories: [SessionCategoryRecord]) -> [UUID] {
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

    func persistedCaptureCategoryIDs(_ state: State) -> [UUID] {
        normalizedCategoryIDs(
            state.captureDraft.selectedCategoryIDs,
            categories: state.categories
        )
    }

    func ensureCategorySelections(_ state: inout State) {
        state.captureDraft.selectedCategoryIDs = normalizedCategoryIDs(
            state.captureDraft.selectedCategoryIDs,
            categories: state.categories
        )

        let validFilteredCategoryIDs = Set(state.categories.map(\.id))
        state.selectedTaskCategoryFilterIDs = state.selectedTaskCategoryFilterIDs.intersection(validFilteredCategoryIDs)
    }

    func nextPriority(after priority: NotePriority) -> NotePriority {
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
}
