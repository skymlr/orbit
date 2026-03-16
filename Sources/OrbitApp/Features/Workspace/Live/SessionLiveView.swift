import ComposableArchitecture
import Foundation
import SwiftUI

struct SessionLiveView: View {
    private enum Layout {
        static let contentMaxWidth: CGFloat = 700
    }

    private enum TaskNavigationDirection {
        case previous
        case next
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var focusedTaskID: UUID?
    @State private var searchText = ""

    var body: some View {
        liveContent
            .frame(maxWidth: Layout.contentMaxWidth, alignment: .leading)
            .task(id: store.activeSession?.id) {
                focusedTaskID = nil
            }
            .onChange(of: sortedFilteredTaskIDs) { _, newTaskIDs in
                syncFocusedTask(with: newTaskIDs)
            }
            .background {
                if store.activeSession != nil {
                    keyboardShortcutBindings
                }
            }
            .animation(.easeInOut(duration: 0.18), value: store.activeSession?.id)
            .animation(.easeInOut(duration: 0.16), value: store.taskDrafts.count)
    }

    @ViewBuilder
    private var liveContent: some View {
        if store.activeSession != nil {
            activeSessionContent
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search tasks")
        } else {
            inactiveSessionContent
        }
    }

    @ViewBuilder
    private var activeSessionContent: some View {
        if let activeSession = store.activeSession {
            VStack(alignment: .leading, spacing: 16) {
                SessionHeader(
                    session: activeSession,
                    endSessionDraft: store.endSessionDraft,
                    onRename: renameSession(_:),
                    onEndSessionTapped: endSessionButtonTapped,
                    onEndSessionConfirm: confirmEndSession(name:),
                    onEndSessionCancel: cancelEndSession
                )

                SessionTaskFilterBar(store: store)

                tasksContent
            }
            .transition(.orbitMicro)
        }
    }

    @ViewBuilder
    private var inactiveSessionContent: some View {
        switch store.sessionBootstrapState {
        case .loading:
            startupLoadingView
                .transition(.orbitMicro)

        case let .failed(message):
            startupLoadErrorView(message: message)
                .transition(.orbitMicro)

        case .idle, .loaded:
            noActiveSessionView
                .transition(.orbitMicro)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emptyStateTitle)
                .orbitFont(.title3, weight: .semibold)

            HStack(spacing: 6) {
                if store.taskDrafts.isEmpty {
                    Text("Use + or")
                    HotkeyHintLabel(shortcut: store.hotkeys.captureShortcut)
                    Text("to capture your first task for this session.")
                } else {
                    Text(emptyStateSubtitle)
                }
            }
            .orbitFont(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var noActiveSessionView: some View {
        VStack {
            Button {
                startSessionButtonTapped()
            } label: {
                sessionHeroLabel(shortcut: store.hotkeys.startShortcut)
            }
            .buttonStyle(.orbitHero)
            .frame(maxWidth: 500)
            .help("Start Session \(HotkeyHintFormatter.hint(from: store.hotkeys.startShortcut))")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -48)
    }

    private var startupLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading active session…")
                .orbitFont(.subheadline, weight: .semibold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -34)
    }

    private func startupLoadErrorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .orbitFont(.title2)
                .foregroundStyle(.orange)

            Text("Could not load active session")
                .orbitFont(.headline)

            Text(message)
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 480)

            Button("Retry") {
                retryBootstrapButtonTapped()
            }
            .buttonStyle(.orbitSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -34)
    }

    @ViewBuilder
    private var tasksContent: some View {
        if sortedFilteredTasks.isEmpty {
            emptyState
                .transition(.orbitMicro)
        } else {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sortedFilteredTasks) { draft in
                            taskRow(for: draft)
                                .id(draft.id)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .scrollIndicators(.visible)
                .onChange(of: focusedTaskID) { _, _ in
                    scrollFocusedTaskIfNeeded(using: scrollProxy)
                }
            }
            .transition(.orbitMicro)
        }
    }

    private func taskRow(for draft: AppFeature.State.TaskDraft) -> some View {
        ZStack(alignment: .topTrailing) {
            TaskRow(
                draft: draft,
                isKeyboardHighlighted: draft.id == focusedTaskID,
                onKeyboardPopoverDismissed: {
                    DispatchQueue.main.async {
                        if focusedTaskID == draft.id {
                            focusedTaskID = nil
                        }
                    }
                },
                onPrioritySet: { priority in
                    setTaskPriority(draftID: draft.id, priority: priority)
                },
                onToggleCompletion: {
                    toggleTaskCompletion(draftID: draft.id, isCompleted: draft.isCompleted)
                },
                onToggleChecklistLine: { lineIndex in
                    toggleChecklistLine(draftID: draft.id, lineIndex: lineIndex)
                }
            )
            .accessibilityAddTraits(draft.id == focusedTaskID ? .isSelected : [])
            .accessibilityHint("Press Up or Down Arrow to move between tasks. Press Return to edit. Press Space to toggle completion. Press Escape to clear task focus.")

            TaskRowFloatingTools(
                draft: draft,
                onEdit: {
                    editTaskButtonTapped(draftID: draft.id)
                },
                onDelete: {
                    deleteTaskButtonTapped(draftID: draft.id)
                }
            )
            .padding(.top, 10)
            .padding(.trailing, 8)
        }
    }

    private var emptyStateTitle: String {
        if store.taskDrafts.isEmpty {
            return "No tasks yet"
        }
        if !trimmedSearchText.isEmpty {
            return "No tasks match this search"
        }

        let hasCategoryFilters = !store.selectedTaskCategoryFilterIDs.isEmpty
        let hasPriorityFilters = !store.selectedTaskPriorityFilters.isEmpty

        switch (hasCategoryFilters, hasPriorityFilters) {
        case (false, false):
            return "No tasks available"
        case (false, true):
            return "No tasks with this priority"
        case (true, false):
            return "No tasks in this category"
        case (true, true):
            return "No tasks match this category and priority"
        }
    }

    private var emptyStateSubtitle: String {
        if !trimmedSearchText.isEmpty {
            return "Try a different search or clear the search field."
        }
        return "Adjust filters to view other tasks."
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredTaskDrafts: [AppFeature.State.TaskDraft] {
        let tasks = store.filteredTaskDrafts
        guard !trimmedSearchText.isEmpty else { return tasks }
        return tasks.filter(matchesLiveSearch(_:))
    }

    private var sortedFilteredTasks: [AppFeature.State.TaskDraft] {
        sortedTasks(filteredTaskDrafts)
    }

    private var sortedFilteredTaskIDs: [UUID] {
        sortedFilteredTasks.map(\.id)
    }

    private var keyboardShortcutBindings: some View {
        VStack {
            Button {
                focusedTaskEditTriggered()
            } label: {
                EmptyView()
            }
            .keyboardShortcut(.return, modifiers: [])
            .opacity(0)

            Button {
                focusedTaskCompletionToggleTriggered()
            } label: {
                EmptyView()
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)

            Button {
                clearFocusedTaskTriggered()
            } label: {
                EmptyView()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)

            Button {
                focusPreviousTaskTriggered()
            } label: {
                EmptyView()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .opacity(0)

            Button {
                focusNextTaskTriggered()
            } label: {
                EmptyView()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .opacity(0)
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var focusedTaskDraft: AppFeature.State.TaskDraft? {
        guard let focusedTaskID else { return nil }
        return sortedFilteredTasks.first(where: { $0.id == focusedTaskID })
    }

    private func matchesLiveSearch(_ draft: AppFeature.State.TaskDraft) -> Bool {
        draft.markdown.localizedCaseInsensitiveContains(trimmedSearchText)
    }

    private func sortedTasks(_ tasks: [AppFeature.State.TaskDraft]) -> [AppFeature.State.TaskDraft] {
        tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }
            if lhs.priority != rhs.priority {
                return priorityRank(lhs.priority) > priorityRank(rhs.priority)
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func priorityRank(_ priority: NotePriority) -> Int {
        switch priority {
        case .none:
            return 0
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }

    private func renameSession(_ name: String) {
        store.send(.sessionRenameTapped(name))
    }

    private func endSessionButtonTapped() {
        store.send(.endSessionTapped)
    }

    private func confirmEndSession(name: String) {
        store.send(.endSessionConfirmTapped(name: name))
    }

    private func cancelEndSession() {
        store.send(.endSessionCancelTapped)
    }

    private func retryBootstrapButtonTapped() {
        store.send(.retryBootstrapActiveSessionButtonTapped)
    }

    private func setTaskPriority(draftID: UUID, priority: NotePriority) {
        store.send(.sessionTaskPrioritySetTapped(draftID, priority))
    }

    private func toggleTaskCompletion(draftID: UUID, isCompleted: Bool) {
        store.send(.sessionTaskCompletionToggled(draftID, !isCompleted))
    }

    private func toggleChecklistLine(draftID: UUID, lineIndex: Int) {
        store.send(.sessionTaskChecklistLineToggled(draftID, lineIndex))
    }

    private func editTaskButtonTapped(draftID: UUID) {
        store.send(.sessionTaskEditTapped(draftID))
    }

    private func deleteTaskButtonTapped(draftID: UUID) {
        store.send(.sessionTaskDeleteTapped(draftID))
    }

    private func focusedTaskEditTriggered() {
        guard let focusedTaskDraft else { return }
        editTaskButtonTapped(draftID: focusedTaskDraft.id)
    }

    private func clearFocusedTaskTriggered() {
        focusedTaskID = nil
    }

    private func focusPreviousTaskTriggered() {
        moveTaskFocus(.previous)
    }

    private func focusNextTaskTriggered() {
        moveTaskFocus(.next)
    }

    private func focusedTaskCompletionToggleTriggered() {
        guard let focusedTaskDraft else { return }
        toggleTaskCompletion(draftID: focusedTaskDraft.id, isCompleted: focusedTaskDraft.isCompleted)
    }

    private func moveTaskFocus(_ direction: TaskNavigationDirection) {
        let taskIDs = sortedFilteredTaskIDs
        guard !taskIDs.isEmpty else {
            focusedTaskID = nil
            return
        }

        guard let currentFocusedTaskID = focusedTaskID,
              let currentIndex = taskIDs.firstIndex(of: currentFocusedTaskID)
        else {
            focusedTaskID = taskIDs.first
            return
        }

        switch direction {
        case .previous:
            self.focusedTaskID = currentIndex > taskIDs.startIndex
                ? taskIDs[taskIDs.index(before: currentIndex)]
                : taskIDs.first

        case .next:
            let nextIndex = taskIDs.index(after: currentIndex)
            self.focusedTaskID = nextIndex < taskIDs.endIndex
                ? taskIDs[nextIndex]
                : taskIDs.last
        }
    }

    private func syncFocusedTask(with taskIDs: [UUID]) {
        guard !taskIDs.isEmpty else {
            focusedTaskID = nil
            return
        }

        guard let focusedTaskID else {
            return
        }

        if !taskIDs.contains(focusedTaskID) {
            self.focusedTaskID = taskIDs.first
        }
    }

    private func scrollFocusedTaskIfNeeded(using scrollProxy: ScrollViewProxy) {
        guard let focusedTaskID else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            scrollProxy.scrollTo(focusedTaskID, anchor: .center)
        }
    }

    private func startSessionButtonTapped() {
        store.send(.startSessionTapped)
    }

    private func sessionHeroLabel(shortcut: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Start Session")
                    .orbitFont(.title3, weight: .bold)
                Spacer()
                HotkeyHintLabel(shortcut: shortcut, tone: .inverted)
                    .orbitFont(.caption, weight: .semibold, monospacedDigits: true)
            }

            Text("Ignite a new focus orbit")
                .orbitFont(.caption)
                .foregroundStyle(.white.opacity(0.86))
        }
        .foregroundStyle(.white)
    }
}

private extension AppFeature.State.TaskDraft {
    var isCompleted: Bool {
        completedAt != nil
    }
}
