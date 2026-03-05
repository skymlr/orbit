import ComposableArchitecture
import Foundation
import SwiftUI

struct SessionPageView: View {
    private enum Layout {
        static let contentMaxWidth: CGFloat = 700
    }

    private enum TaskNavigationDirection {
        case previous
        case next
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var focusedTaskID: UUID?

    @State private var isHistoryMode = false
    @State private var selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: Date())
    @State private var selectedHistorySessionID: UUID?
    @State private var isHistoryCalendarPresented = false
    @State private var historyTaskFilter: HistoryTaskFilter = .completed

    var body: some View {
        Group {
            if isHistoryMode {
                historyBrowserContent
            } else if let activeSession = store.activeSession {
                VStack(alignment: .leading, spacing: 16) {
                    SessionHeader(
                        session: activeSession,
                        onRename: { name in
                            store.send(.sessionRenameTapped(name))
                        }
                    )

                    SessionTaskFilterBar(store: store)

                    tasksContent
                }
                .frame(maxWidth: Layout.contentMaxWidth, alignment: .leading)
                .transition(.orbitMicro)
            } else {
                noActiveSessionContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(18)
        .frame(minWidth: 880, minHeight: 640)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.send(.sessionAddTaskTapped)
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .help("Capture Task \(HotkeyHintFormatter.hint(from: store.hotkeys.captureShortcut))")

                Button {
                    isHistoryCalendarPresented = true
                } label: {
                    Image(systemName: "calendar")
                }
                .help("Browse session history by day")
                .popover(isPresented: $isHistoryCalendarPresented, arrowEdge: .bottom) {
                    historyCalendarPopover
                }

                if isHistoryMode {
                    Button {
                        navigateHistoryDay(.previous)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(previousHistoryDay == nil)
                    .help("Older session day")

                    Button {
                        navigateHistoryDay(.next)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(nextHistoryDay == nil)
                    .help("Newer session day")
                }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .task(id: store.activeSession?.id) {
            focusedTaskID = nil
            reconcileHistorySelection()
        }
        .onChange(of: sortedFilteredTaskIDs) { _, newTaskIDs in
            syncFocusedTask(with: newTaskIDs)
        }
        .onChange(of: historyDayGroups) { _, _ in
            reconcileHistorySelection()
        }
        .onChange(of: selectedHistoryDay) { _, newDay in
            let normalized = SessionHistoryBrowserSupport.normalizedDay(for: newDay)
            if selectedHistoryDay != normalized {
                selectedHistoryDay = normalized
                return
            }
            selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
                on: normalized,
                groups: historyDayGroups
            )
        }
        .background {
            if !isHistoryMode {
                keyboardShortcutBindings
            }
        }
        .background {
            OrbitSpaceBackground()
        }
        .animation(.easeInOut(duration: 0.18), value: store.activeSession?.id)
        .animation(.easeInOut(duration: 0.16), value: store.taskDrafts.count)
        .animation(.easeInOut(duration: 0.16), value: isHistoryMode)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emptyStateTitle)
                .font(.title3.weight(.semibold))
            HStack(spacing: 6) {
                if store.taskDrafts.isEmpty {
                    Text("Use + or")
                    HotkeyHintLabel(shortcut: store.hotkeys.captureShortcut)
                    Text("to capture your first task for this session.")
                } else {
                    Text(emptyStateSubtitle)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var historyBrowserContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Read-Only Session History")
                .font(.title3.weight(.bold))

            if let activeSession = store.activeSession {
                CurrentSessionHistoryBanner(
                    session: activeSession,
                    onBackToLiveSession: {
                        exitHistoryMode()
                    }
                )
            } else {
                HStack(spacing: 10) {
                    Text("No active session. You are browsing archived history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Exit History") {
                        exitHistoryMode()
                    }
                    .buttonStyle(.orbitSecondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
            }

            if historyDayGroups.isEmpty {
                historyContentUnavailableState(
                    message: "No completed sessions yet. End a session to build your history timeline."
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(SessionHistoryBrowserSupport.dayLabel(selectedHistoryDay))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.cyan)

                    Text("\(selectedHistoryDaySessions.count) \(selectedHistoryDaySessions.count == 1 ? "session" : "sessions")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if selectedHistoryDaySessions.isEmpty {
                    historyContentUnavailableState(
                        message: "No sessions on this day. Use the arrows or calendar to jump to a day with saved sessions."
                    )
                } else {
                    HistorySessionStripView(
                        sessions: selectedHistoryDaySessions,
                        selectedSessionID: selectedHistorySession?.id,
                        onSelect: { sessionID in
                            selectedHistorySessionID = sessionID
                        }
                    )

                    if let selectedHistorySession {
                        HistoryTaskListView(
                            session: selectedHistorySession,
                            filteredTasks: historyFilteredTasks,
                            historyTaskFilter: $historyTaskFilter
                        )
                    }
                }
            }
        }
        .frame(maxWidth: Layout.contentMaxWidth, alignment: .leading)
        .transition(.orbitMicro)
    }

    private func historyContentUnavailableState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Sessions To Show")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var historyCalendarPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Jump To Day")
                .font(.headline)

            HistoryCalendarPickerView(
                availableDays: Set(historyDayGroups.map(\.day)),
                selectedDay: selectedHistoryDay,
                onSelectDay: { selectedDay in
                    enterHistoryMode(on: selectedDay)
                    isHistoryCalendarPresented = false
                }
            )
        }
        .padding(12)
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

    @ViewBuilder
    private var noActiveSessionContent: some View {
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

    private var startupLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading active session…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -34)
    }

    private func startupLoadErrorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Could not load active session")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 480)

            Button("Retry") {
                store.send(.retryBootstrapActiveSessionButtonTapped)
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
                    .padding(8)
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
                    store.send(.sessionTaskPrioritySetTapped(draft.id, priority))
                },
                onToggleCompletion: {
                    store.send(.sessionTaskCompletionToggled(draft.id, !draft.isCompleted))
                },
                onToggleChecklistLine: { lineIndex in
                    store.send(.sessionTaskChecklistLineToggled(draft.id, lineIndex))
                }
            )
            .accessibilityAddTraits(draft.id == focusedTaskID ? .isSelected : [])
            .accessibilityHint("Press Up or Down Arrow to move between tasks. Press Return to edit. Press Space to toggle completion. Press Escape to clear task focus.")

            TaskRowFloatingTools(
                draft: draft,
                onEdit: {
                    store.send(.sessionTaskEditTapped(draft.id))
                },
                onDelete: {
                    store.send(.sessionTaskDeleteTapped(draft.id))
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
        "Adjust filters to view other tasks."
    }

    private var sortedFilteredTasks: [AppFeature.State.TaskDraft] {
        sortedTasks(store.filteredTaskDrafts)
    }

    private var sortedFilteredTaskIDs: [UUID] {
        sortedFilteredTasks.map(\.id)
    }

    private var historyDayGroups: [HistoryDayGroup] {
        SessionHistoryBrowserSupport.dayGroups(
            from: store.settings.sessions,
            excludingActiveSessionID: store.activeSession?.id
        )
    }

    private var selectedHistoryDaySessions: [FocusSessionRecord] {
        SessionHistoryBrowserSupport.sessions(on: selectedHistoryDay, from: historyDayGroups)
    }

    private var selectedHistorySession: FocusSessionRecord? {
        SessionHistoryBrowserSupport.resolveSelectedSession(
            id: selectedHistorySessionID,
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
    }

    private var historyFilteredTasks: [FocusTaskRecord] {
        guard let selectedHistorySession else { return [] }
        return SessionHistoryBrowserSupport.filteredTasks(
            for: selectedHistorySession,
            filter: historyTaskFilter
        )
    }

    private var previousHistoryDay: Date? {
        SessionHistoryBrowserSupport.adjacentDay(
            from: selectedHistoryDay,
            groups: historyDayGroups,
            direction: .previous
        )
    }

    private var nextHistoryDay: Date? {
        SessionHistoryBrowserSupport.adjacentDay(
            from: selectedHistoryDay,
            groups: historyDayGroups,
            direction: .next
        )
    }

    private var keyboardShortcutBindings: some View {
        HStack(spacing: 0) {
            Button(action: clearFocusedTaskTriggered) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(focusedTaskID == nil)

            Button(action: focusNextTaskTriggered) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.tab, modifiers: [])
            .disabled(sortedFilteredTaskIDs.isEmpty)

            Button(action: focusPreviousTaskTriggered) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.tab, modifiers: [.shift])
            .disabled(sortedFilteredTaskIDs.isEmpty)

            Button(action: focusPreviousTaskTriggered) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(focusedTaskID == nil)

            Button(action: focusNextTaskTriggered) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(focusedTaskID == nil)

            Button(action: focusedTaskEditTriggered) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(focusedTaskID == nil)

            Button(action: focusedTaskCompletionToggleTriggered) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(focusedTaskID == nil)
        }
        .frame(width: 0, height: 0)
        .clipped()
        .opacity(0.001)
    }

    private func sortedTasks(_ tasks: [AppFeature.State.TaskDraft]) -> [AppFeature.State.TaskDraft] {
        tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            let lhsPriorityRank = priorityRank(lhs.priority)
            let rhsPriorityRank = priorityRank(rhs.priority)
            if lhsPriorityRank != rhsPriorityRank {
                return lhsPriorityRank < rhsPriorityRank
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func priorityRank(_ priority: NotePriority) -> Int {
        switch priority {
        case .high:
            return 0
        case .medium:
            return 1
        case .low:
            return 2
        case .none:
            return 3
        }
    }

    private func focusedTaskEditTriggered() {
        guard let focusedTaskID else { return }
        store.send(.sessionTaskEditTapped(focusedTaskID))
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
        guard let focusedTask = focusedTaskDraft else { return }
        store.send(.sessionTaskCompletionToggled(focusedTask.id, !focusedTask.isCompleted))
    }

    private func moveTaskFocus(_ direction: TaskNavigationDirection) {
        let taskIDs = sortedFilteredTaskIDs
        guard !taskIDs.isEmpty else {
            focusedTaskID = nil
            return
        }

        guard let focusedTaskID,
              let currentIndex = taskIDs.firstIndex(of: focusedTaskID)
        else {
            self.focusedTaskID = direction == .next ? taskIDs.first : taskIDs.last
            return
        }

        let nextIndex: Int
        switch direction {
        case .previous:
            nextIndex = (currentIndex - 1 + taskIDs.count) % taskIDs.count
        case .next:
            nextIndex = (currentIndex + 1) % taskIDs.count
        }
        self.focusedTaskID = taskIDs[nextIndex]
    }

    private func syncFocusedTask(with taskIDs: [UUID]) {
        guard !taskIDs.isEmpty else {
            focusedTaskID = nil
            return
        }
        guard let focusedTaskID else { return }
        if !taskIDs.contains(focusedTaskID) {
            self.focusedTaskID = nil
        }
    }

    private var focusedTaskDraft: AppFeature.State.TaskDraft? {
        guard let focusedTaskID else { return nil }
        return sortedFilteredTasks.first(where: { $0.id == focusedTaskID })
    }

    private func scrollFocusedTaskIfNeeded(using scrollProxy: ScrollViewProxy) {
        guard let focusedTaskID else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            scrollProxy.scrollTo(focusedTaskID, anchor: .center)
        }
    }

    private func startSessionButtonTapped() {
        store.send(.startSessionTapped)
    }

    private func enterHistoryMode(on day: Date) {
        let wasHistoryMode = isHistoryMode
        isHistoryMode = true
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )

        if !wasHistoryMode {
            historyTaskFilter = .completed
        }
    }

    private func exitHistoryMode() {
        isHistoryMode = false
    }

    private func navigateHistoryDay(_ direction: HistoryDayNavigationDirection) {
        guard let nextDay = SessionHistoryBrowserSupport.adjacentDay(
            from: selectedHistoryDay,
            groups: historyDayGroups,
            direction: direction
        ) else {
            return
        }

        selectedHistoryDay = nextDay
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: nextDay,
            groups: historyDayGroups
        )
    }

    private func reconcileHistorySelection() {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: selectedHistoryDay)
        selectedHistorySessionID = SessionHistoryBrowserSupport.resolveSelectedSession(
            id: selectedHistorySessionID,
            on: selectedHistoryDay,
            groups: historyDayGroups
        )?.id
    }

    @ViewBuilder
    private func sessionHeroLabel(shortcut: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "atom")
                    .font(.title3.weight(.semibold))
                Text("Start Session")
                    .font(.title3.weight(.bold))
                Spacer()
                HotkeyHintLabel(shortcut: shortcut, tone: .inverted)
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            Text("Ignite a new focus orbit")
                .font(.caption)
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

private struct CurrentSessionHistoryBanner: View {
    let session: FocusSessionRecord
    let onBackToLiveSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Session")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(session.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                Button("Back to Live Session") {
                    onBackToLiveSession()
                }
                .buttonStyle(.orbitPrimary)
            }

            HStack(spacing: 8) {
                Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                Text("•")
                Text("Started \(session.startedAt, style: .time)")
                Text("•")
                Text("Elapsed \(session.startedAt, style: .timer)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.cyan.opacity(0.62), lineWidth: 1)
                )
        )
    }
}

private struct HistorySessionStripView: View {
    let sessions: [FocusSessionRecord]
    let selectedSessionID: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(sessions) { session in
                    sessionButton(for: session)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func sessionButton(for session: FocusSessionRecord) -> some View {
        let isSelected = session.id == selectedSessionID
        let taskCountLabel = "\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")"

        return Button {
            onSelect(session.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text("Started \(session.startedAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(taskCountLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 164, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.cyan.opacity(0.86) : Color.white.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.name)
        .accessibilityHint("Open this session in read-only mode")
    }
}

private struct HistoryTaskListView: View {
    let session: FocusSessionRecord
    let filteredTasks: [FocusTaskRecord]
    @Binding var historyTaskFilter: HistoryTaskFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.title3.weight(.semibold))

                HStack(spacing: 8) {
                    Text("Started \(session.startedAt, style: .time)")

                    if let endedAt = session.endedAt {
                        Text("•")
                        Text("Ended \(endedAt, style: .time)")
                    }

                    Text("•")
                    Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Picker("Task filter", selection: $historyTaskFilter) {
                ForEach(HistoryTaskFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            if filteredTasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No tasks for this filter")
                        .font(.subheadline.weight(.semibold))
                    Text("Try switching between Completed, All, and Open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredTasks) { task in
                            HistoryTaskRowView(task: task)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
            }
        }
    }
}

private struct HistoryCalendarPickerView: View {
    let availableDays: Set<Date>
    let selectedDay: Date
    let onSelectDay: (Date) -> Void

    @State private var displayedMonthStart: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(
        availableDays: Set<Date>,
        selectedDay: Date,
        onSelectDay: @escaping (Date) -> Void
    ) {
        self.availableDays = availableDays
        self.selectedDay = selectedDay
        self.onSelectDay = onSelectDay
        _displayedMonthStart = State(initialValue: Self.monthStart(for: selectedDay, calendar: .current))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.orbitQuiet)

                Spacer()

                Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.orbitQuiet)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthDayCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear
                            .frame(height: 26)
                    }
                }
            }
        }
    }

    private var normalizedAvailableDays: Set<Date> {
        Set(availableDays.map { calendar.startOfDay(for: $0) })
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        guard symbols.indices.contains(firstWeekdayIndex) else { return symbols }
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    private var monthDayCells: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: displayedMonthStart)
        let leadingEmptyCells = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells = Array(repeating: Date?.none, count: leadingEmptyCells)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: displayedMonthStart) {
                cells.append(date)
            }
        }

        let trailingCells = (7 - (cells.count % 7)) % 7
        if trailingCells > 0 {
            cells.append(contentsOf: Array(repeating: Date?.none, count: trailingCells))
        }
        return cells
    }

    private func dayButton(_ day: Date) -> some View {
        let normalizedDay = calendar.startOfDay(for: day)
        let isEnabled = normalizedAvailableDays.contains(normalizedDay)
        let isSelected = calendar.isDate(normalizedDay, inSameDayAs: selectedDay)
        let dayNumber = calendar.component(.day, from: normalizedDay)
        let backgroundColor = dayBackgroundColor(isEnabled: isEnabled, isSelected: isSelected)
        let borderColor = dayBorderColor(isEnabled: isEnabled, isSelected: isSelected)
        let foregroundColor = dayForegroundColor(isEnabled: isEnabled)

        return Button {
            onSelectDay(normalizedDay)
        } label: {
            Text("\(dayNumber)")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .foregroundStyle(foregroundColor)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(normalizedDay.formatted(date: .abbreviated, time: .omitted))
        .accessibilityHint(isEnabled ? "Open history for this day" : "No historical sessions on this day")
    }

    private func moveMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: displayedMonthStart) else { return }
        displayedMonthStart = Self.monthStart(for: month, calendar: calendar)
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func dayBackgroundColor(isEnabled: Bool, isSelected: Bool) -> Color {
        if isSelected { return Color.cyan.opacity(0.30) }
        if isEnabled { return Color.cyan.opacity(0.16) }
        return Color.clear
    }

    private func dayBorderColor(isEnabled: Bool, isSelected: Bool) -> Color {
        if isSelected { return Color.cyan.opacity(0.92) }
        if isEnabled { return Color.cyan.opacity(0.45) }
        return Color.white.opacity(0.12)
    }

    private func dayForegroundColor(isEnabled: Bool) -> Color {
        isEnabled ? Color.primary : Color.secondary.opacity(0.35)
    }
}

private struct SessionHeader: View {
    let session: FocusSessionRecord
    let onRename: (String) -> Void

    @State private var isRenaming = false
    @State private var name = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if isRenaming {
                    TextField("Session name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2.weight(.bold))
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            saveRenaming()
                        }
                        .onExitCommand {
                            cancelRenaming()
                        }
                } else {
                    Text(session.name)
                        .font(.largeTitle.weight(.bold))
                        .lineLimit(2)
                        .contentShape(Rectangle())
                        .orbitPointerCursor()
                        .onTapGesture {
                            beginRenaming()
                        }
                }

                Spacer(minLength: 10)

                if isRenaming {
                    Button("Save") {
                        saveRenaming()
                    }
                    .buttonStyle(.orbitSecondary)
                    .disabled(trimmedName.isEmpty)
                }
            }

            HStack(spacing: 8) {
                Text("Started \(session.startedAt, style: .time)")
                Text("•")
                Text("Elapsed \(session.startedAt, style: .timer)")
                Text("•")
                Text("Ends at \(FocusDefaults.nextSessionBoundary(after: session.startedAt), style: .time)")

                Spacer()

                Text("\(openTaskCount) open")
                Text("•")
                Text("\(completedTaskCount) completed")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .task(id: session.id) {
            name = session.name
            isRenaming = false
        }
        .onChange(of: session.name) { _, newValue in
            if !isRenaming {
                name = newValue
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var completedTaskCount: Int {
        session.tasks.reduce(into: 0) { count, task in
            if task.completedAt != nil {
                count += 1
            }
        }
    }

    private var openTaskCount: Int {
        max(0, session.tasks.count - completedTaskCount)
    }

    private func beginRenaming() {
        isRenaming = true
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func saveRenaming() {
        guard !trimmedName.isEmpty else { return }
        onRename(trimmedName)
        isRenaming = false
    }

    private func cancelRenaming() {
        name = session.name
        isRenaming = false
    }
}
