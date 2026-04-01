import ComposableArchitecture
import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

struct SessionLiveView: View {
    private enum Layout {
#if os(macOS)
        static let contentMaxWidth: CGFloat = 1_180
        static let sessionInfoWidth: CGFloat = 320
        static let splitSpacing: CGFloat = 20
        static let collapseThreshold: CGFloat = 980
#else
        static let contentMaxWidth: CGFloat = 700
#endif
        static let taskSpacing: CGFloat = 12
        static let phoneContentInsets = EdgeInsets(top: 20, leading: 16, bottom: 28, trailing: 16)
    }

    private enum TaskNavigationDirection {
        case previous
        case next
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.orbitAdaptiveLayout) private var layout
    @State private var focusedTaskID: UUID?
    @State private var isTaskFilterPopoverPresented = false
    @State private var isSessionInfoPresented = false
#if os(macOS)
    @State private var isMacSessionInfoCollapsed = false
#endif

    var body: some View {
        liveContent
            .frame(
                maxWidth: layout.isCompact ? .infinity : Layout.contentMaxWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .task(id: renderedActiveSession?.id) {
                focusedTaskID = nil
            }
            .onChange(of: sortedFilteredTaskIDs) { _, newTaskIDs in
                syncFocusedTask(with: newTaskIDs)
            }
            .onChange(of: renderedActiveSession?.id) { oldValue, newValue in
                if oldValue != newValue {
                    isTaskFilterPopoverPresented = false
                    isSessionInfoPresented = false
                }
            }
            .background {
                if renderedActiveSession != nil {
                    keyboardShortcutBindings
                }
            }
            .toolbar {
                sessionInfoToolbarContent
            }
#if os(iOS)
            .background {
                if layout.isCompact {
                    OrbitSpaceBackground(
                        style: store.appearance.background,
                        showsOrbitalLayer: store.appearance.showsOrbitalLayer
                    )
                }
            }
#endif
            .animation(.easeInOut(duration: 0.18), value: renderedActiveSession?.id)
            .animation(.easeInOut(duration: 0.16), value: renderedTaskDrafts.count)
    }

    @ViewBuilder
    private var liveContent: some View {
        if renderedActiveSession != nil {
            activeSessionContent
        } else {
            inactiveSessionContent
        }
    }

    @ViewBuilder
    private var activeSessionContent: some View {
        if let activeSession = renderedActiveSession {
#if os(macOS)
            GeometryReader { proxy in
                let isCollapsed = shouldCollapseMacSessionInfo(for: proxy.size.width)

                Group {
                    if isCollapsed {
                        taskScrollView
                    } else {
                        HStack(alignment: .top, spacing: Layout.splitSpacing) {
                            sessionInfoSidebar(for: activeSession)
                            taskScrollView
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .onAppear {
                    updateMacSessionInfoCollapse(width: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, newWidth in
                    updateMacSessionInfoCollapse(width: newWidth)
                }
            }
            .transition(.orbitMicro)
#else
            taskScrollView
                .transition(.orbitMicro)
#endif
        }
    }

    @ViewBuilder
    private var inactiveSessionContent: some View {
        if isPhone {
            GeometryReader { proxy in
                ScrollView {
                    inactiveSessionState
                        .frame(
                            maxWidth: .infinity,
                            minHeight: max(
                                0,
                                proxy.size.height
                                    - Layout.phoneContentInsets.top
                                    - Layout.phoneContentInsets.bottom
                            ),
                            alignment: .center
                        )
                        .padding(Layout.phoneContentInsets)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scrollIndicators(.hidden)
            }
        } else {
            inactiveSessionState
        }
    }

    @ViewBuilder
    private var inactiveSessionState: some View {
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
                if renderedTaskDrafts.isEmpty {
                    if store.platform.supportsGlobalHotkeys {
                        Text("Use + or")
                        HotkeyHintLabel(shortcut: store.hotkeys.captureShortcut)
                        Text("to capture your first task for this session.")
                    } else {
                        Text("Use + to capture your first task for this session.")
                    }
                } else {
                    Text(emptyStateSubtitle)
                }
            }
            .orbitFont(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .orbitSurfaceCard()
    }

    private var noActiveSessionView: some View {
        SessionLiveNoActiveSessionView(
            maxButtonWidth: layout.isCompact ? nil : 500,
            helpText: store.platform.supportsGlobalHotkeys
                ? "Start Session \(HotkeyHintFormatter.hint(from: store.hotkeys.startShortcut))"
                : "Start Session",
            verticalOffset: inactiveStateVerticalOffset,
            action: startSessionButtonTapped
        ) {
            sessionHeroLabel(shortcut: store.hotkeys.startShortcut)
        }
    }

    private var startupLoadingView: some View {
        SessionLiveLoadingStateView(verticalOffset: statusStateVerticalOffset)
    }

    private func startupLoadErrorView(message: String) -> some View {
        SessionLiveErrorStateView(
            message: message,
            verticalOffset: statusStateVerticalOffset,
            retryAction: retryBootstrapButtonTapped
        )
    }

    @ViewBuilder
    private var taskSectionContent: some View {
        if sortedFilteredTasks.isEmpty {
            emptyState
                .padding(.top, 4)
                .transition(.orbitMicro)
        } else {
            ForEach(Array(sortedFilteredTasks.enumerated()), id: \.element.id) { entry in
                let index = entry.offset
                let draft = entry.element

                taskRow(for: draft)
                    .id(draft.id)
                    .padding(.top, index == 0 ? 4 : 0)
                    .padding(.bottom, Layout.taskSpacing)
                    .transition(.orbitMicro)
            }
        }
    }

    private var stickyFilterBar: some View {
        SessionTaskFilterBar(store: store)
    }

    @ViewBuilder
    private var taskScrollView: some View {
        SessionLiveTaskListView(
            usesPhoneListLayout: isPhone,
            hasSelectedFilters: hasSelectedFilters,
            topPadding: scrollContentTopPadding,
            horizontalPadding: scrollContentHorizontalPadding,
            bottomPadding: scrollContentBottomPadding,
            trailingPadding: scrollContentTrailingPadding,
            focusedTaskID: $focusedTaskID
        ) {
            compactSessionOverviewCard
        } filterBar: {
            stickyFilterBar
        } taskContent: {
            taskSectionContent
        }
    }

    private var scrollContentTopPadding: CGFloat {
#if os(iOS)
        if isPhone {
            return Layout.phoneContentInsets.top
        }
        return layout.isCompact ? 0 : 6
#else
        return 0
#endif
    }

    private var scrollContentHorizontalPadding: CGFloat {
        isPhone ? Layout.phoneContentInsets.leading : 0
    }

    private var scrollContentBottomPadding: CGFloat {
        isPhone ? Layout.phoneContentInsets.bottom : 0
    }

    private var scrollContentTrailingPadding: CGFloat {
        isPhone ? 0 : (layout.isCompact ? 0 : 8)
    }

    private var inactiveStateVerticalOffset: CGFloat {
        layout.isCompact ? 0 : -48
    }

    private var statusStateVerticalOffset: CGFloat {
        layout.isCompact ? 0 : -34
    }

    private var isPhone: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }

    @ToolbarContentBuilder
    private var sessionInfoToolbarContent: some ToolbarContent {
#if os(macOS)
        if let activeSession = renderedActiveSession {
            if isMacSessionInfoCollapsed {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isSessionInfoPresented.toggle()
                    } label: {
                        Text(activeSession.name)
                            .orbitFont(.headline)
                    }
                    .help("Session Info")
                    .popover(isPresented: $isSessionInfoPresented, arrowEdge: .bottom) {
                        sessionInfoPresentation(for: activeSession)
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                taskFilterToolbarButton
            }
        }
#else
        if isPhone {
            if renderedActiveSession != nil {
                ToolbarItem(placement: .topBarLeading) {
                    taskFilterToolbarButton
                }
            }

            if let activeSession = renderedActiveSession, layout.isCompact {
                ToolbarItem(placement: .principal) {
                    sessionInfoToolbarButton(for: activeSession)
                }
            } else if let activeSession = renderedActiveSession {
                ToolbarSpacer(.fixed, placement: .topBarLeading)
                ToolbarItem(placement: .topBarLeading) {
                    sessionInfoToolbarButton(for: activeSession)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                quickCaptureToolbarButton
            }
        } else if let activeSession = renderedActiveSession {
            if layout.isCompact {
                ToolbarItem(placement: .principal) {
                    sessionInfoToolbarButton(for: activeSession)
                }
            } else {
                ToolbarSpacer(.fixed, placement: .topBarLeading)
                ToolbarItem(placement: .topBarLeading) {
                    sessionInfoToolbarButton(for: activeSession)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                taskFilterToolbarButton
            }
        }
#endif
    }

    private var taskFilterToolbarButton: some View {
        SessionTaskFilterToolbarButton(
            store: store,
            isTaskFilterPopoverPresented: $isTaskFilterPopoverPresented
        )
    }

    private var quickCaptureToolbarButton: some View {
        Button(action: quickCaptureButtonTapped) {
            Image(systemName: "plus")
        }
        .buttonStyle(.glassProminent)
        .accessibilityLabel("Quick Capture")
        .accessibilityHint("Capture a task from the current session")
    }

    private func quickCaptureButtonTapped() {
        if store.activeSession == nil {
            store.send(.captureTapped)
        } else {
            store.send(.sessionAddTaskTapped)
        }
    }

    @ViewBuilder
    private var compactSessionOverviewCard: some View {
#if os(iOS)
        if layout.isCompact, let activeSession = renderedActiveSession {
            Button {
                isSessionInfoPresented = true
            } label: {
                OrbitIndexCard(
                    systemImage: "checklist",
                    title: activeSession.name,
                    subtitle: liveSessionSummary(for: activeSession)
                )
            }
            .buttonStyle(.plain)
        }
#endif
    }

    @ViewBuilder
    private func sessionInfoToolbarButton(for activeSession: FocusSessionRecord) -> some View {
        if layout.isCompact {
            Button {
                isSessionInfoPresented.toggle()
            } label: {
                Text(activeSession.name)
                    .orbitFont(.subheadline, weight: .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .accessibilityLabel("Session Info")
            .accessibilityHint("Open current session information")
            .sheet(isPresented: $isSessionInfoPresented) {
                sessionInfoPresentation(for: activeSession)
            }
        } else {
            Button {
                isSessionInfoPresented.toggle()
            } label: {
                Text(activeSession.name)
                    .orbitFont(.headline)
            }
            .accessibilityLabel("Session Info")
            .accessibilityHint("Open current session information")
            .popover(isPresented: $isSessionInfoPresented, arrowEdge: .top) {
                sessionInfoPresentation(for: activeSession)
            }
        }
    }

    @ViewBuilder
    private func sessionInfoPresentation(for session: FocusSessionRecord) -> some View {
        let surface = SessionInfoSurface(
            session: session,
            endSessionDraft: store.endSessionDraft,
            taskDrafts: renderedTaskDrafts,
            style: .presentation,
            onRename: renameSession(_:),
            onEndSessionTapped: endSessionButtonTapped,
            onEndSessionConfirm: confirmEndSession(name:),
            onEndSessionCancel: cancelEndSession
        )

        if layout.isCompact {
            NavigationStack {
                surface
                    .navigationTitle("Session Info")
                    .orbitInlineNavigationTitleDisplayMode()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isSessionInfoPresented = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        } else {
            surface
                .presentationCompactAdaptation(.sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationSizing(.fitted)
        }
    }

#if os(macOS)
    private func sessionInfoSidebar(for session: FocusSessionRecord) -> some View {
        SessionInfoSurface(
            session: session,
            endSessionDraft: store.endSessionDraft,
            taskDrafts: renderedTaskDrafts,
            style: .card,
            onRename: renameSession(_:),
            onEndSessionTapped: endSessionButtonTapped,
            onEndSessionConfirm: confirmEndSession(name:),
            onEndSessionCancel: cancelEndSession
        )
        .frame(width: Layout.sessionInfoWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func shouldCollapseMacSessionInfo(for width: CGFloat) -> Bool {
        width < Layout.collapseThreshold
    }

    private func updateMacSessionInfoCollapse(width: CGFloat) {
        let isCollapsed = shouldCollapseMacSessionInfo(for: width)
        if isMacSessionInfoCollapsed != isCollapsed {
            isMacSessionInfoCollapsed = isCollapsed
        }
        if !isCollapsed {
            isSessionInfoPresented = false
        }
    }
#endif

    private func taskRow(for draft: AppFeature.State.TaskDraft) -> some View {
        SessionTaskInteractiveRow(
            draft: draft,
            isKeyboardHighlighted: draft.id == focusedTaskID,
            onKeyboardPopoverDismissed: {
                DispatchQueue.main.async {
                    if focusedTaskID == draft.id {
                        focusedTaskID = nil
                    }
                }
            },
            onEditRequested: {
                editTaskButtonTapped(draftID: draft.id)
            },
            onPrioritySet: { priority in
                setTaskPriority(draftID: draft.id, priority: priority)
            },
            onToggleCompletion: {
                toggleTaskCompletion(draftID: draft.id, isCompleted: draft.isCompleted)
            },
            onToggleChecklistLine: { lineIndex in
                toggleChecklistLine(draftID: draft.id, lineIndex: lineIndex)
            },
            onDeleteRequested: {
                deleteTaskButtonTapped(draftID: draft.id)
            }
        )
    }

    private var emptyStateTitle: String {
        if renderedTaskDrafts.isEmpty {
            return "No tasks yet"
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
        return "Adjust filters to view other tasks."
    }

    private var hasSelectedFilters: Bool {
        !store.selectedTaskCategoryFilterIDs.isEmpty || !store.selectedTaskPriorityFilters.isEmpty
    }

    private var renderedActiveSession: FocusSessionRecord? {
        store.activeSession
    }

    private var renderedTaskDrafts: [AppFeature.State.TaskDraft] {
        Array(store.taskDrafts)
    }

    private var sortedFilteredTasks: [AppFeature.State.TaskDraft] {
        SessionTaskDraftSearchSupport.filteredTasks(
            from: renderedTaskDrafts,
            selectedCategoryFilterIDs: store.selectedTaskCategoryFilterIDs,
            selectedPriorityFilters: store.selectedTaskPriorityFilters,
            searchText: ""
        )
    }

    private var liveCompletedTaskCount: Int {
        renderedTaskDrafts.reduce(into: 0) { count, task in
            if task.completedAt != nil {
                count += 1
            }
        }
    }

    private var liveOpenTaskCount: Int {
        max(0, renderedTaskDrafts.count - liveCompletedTaskCount)
    }

    private func liveSessionSummary(for session: FocusSessionRecord) -> String {
        let startedAt = session.startedAt.formatted(date: .omitted, time: .shortened)
        let openTaskLabel = "\(liveOpenTaskCount) open"
        let completedTaskLabel = "\(liveCompletedTaskCount) completed"
        return "Started \(startedAt) • \(openTaskLabel) • \(completedTaskLabel)"
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

    private func startSessionButtonTapped() {
        store.send(.startSessionTapped)
    }

    private func sessionHeroLabel(shortcut: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Start Session")
                    .orbitFont(.title3, weight: .bold)
                Spacer()
                if store.platform.supportsGlobalHotkeys {
                    HotkeyHintLabel(shortcut: shortcut, tone: .inverted)
                        .orbitFont(.caption, weight: .semibold, monospacedDigits: true)
                }
            }

            Text("Ignite a new focus orbit")
                .orbitFont(.caption)
                .foregroundStyle(.white.opacity(0.86))
        }
        .foregroundStyle(.white)
    }
}
