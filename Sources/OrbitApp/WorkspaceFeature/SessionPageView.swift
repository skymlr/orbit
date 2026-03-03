import ComposableArchitecture
import Foundation
import SwiftUI

struct SessionPageView: View {
    private enum Layout {
        static let contentMaxWidth: CGFloat = 700
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var isEndSessionConfirmationPending = false
    @State private var endSessionConfirmationToken = 0

    var body: some View {
        Group {
            if let activeSession = store.activeSession {
                VStack(alignment: .leading, spacing: 16) {
                    SessionHeader(
                        session: activeSession,
                        onRename: { name in
                            store.send(.sessionRenameTapped(name))
                        }
                    )

                    taskCategoryFilterBar

                    tasksContent
                    endSessionControl
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
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .task(id: store.activeSession?.id) {
            isEndSessionConfirmationPending = false
            endSessionConfirmationToken += 1
        }
        .background {
            OrbitSpaceBackground()
        }
        .animation(.easeInOut(duration: 0.18), value: store.activeSession?.id)
        .animation(.easeInOut(duration: 0.16), value: store.taskDrafts.count)
        .animation(.easeInOut(duration: 0.16), value: isEndSessionConfirmationPending)
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
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedFilteredTasks) { draft in
                        taskRow(for: draft)
                    }
                }
            }
            .scrollIndicators(.visible)
            .transition(.orbitMicro)
        }
    }

    private var taskCategoryFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterChip(
                    title: "All",
                    count: store.taskDrafts.count,
                    isSelected: isAllFilterSelected
                ) {
                    store.send(.sessionTaskCategoryFilterChangedTapped(.all))
                }

                ForEach(categoriesWithTasks) { category in
                    filterChip(
                        title: category.name,
                        count: countForCategory(category.id),
                        isSelected: isCategorySelected(category.id),
                        tint: Color(categoryHex: category.colorHex)
                    ) {
                        store.send(.sessionTaskCategoryFilterChangedTapped(.category(category.id)))
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var endSessionControl: some View {
        HStack {
            Spacer()
            if isEndSessionConfirmationPending {
                Button("Confirm End Session", role: .destructive) {
                    store.send(.workspaceWindowEndSessionTapped)
                }
                .buttonStyle(.orbitDestructive)
                .transition(.orbitMicro)
            } else {
                Button("End Session") {
                    endSessionButtonTapped()
                }
                .buttonStyle(.orbitQuiet)
                .transition(.orbitMicro)
            }
        }
        .padding(.top, 2)
    }

    private func taskRow(for draft: AppFeature.State.TaskDraft) -> some View {
        TaskRow(
            draft: draft,
            onEdit: {
                store.send(.sessionTaskEditTapped(draft.id))
            },
            onToggleCompletion: {
                store.send(.sessionTaskCompletionToggled(draft.id, !draft.isCompleted))
            },
            onDelete: {
                store.send(.sessionTaskDeleteTapped(draft.id))
            }
        )
    }

    private var isAllFilterSelected: Bool {
        switch store.selectedTaskCategoryFilter {
        case .all:
            return true
        case .category:
            return false
        }
    }

    private var emptyStateTitle: String {
        if store.taskDrafts.isEmpty {
            return "No tasks yet"
        }
        return "No tasks in this category"
    }

    private var emptyStateSubtitle: String {
        "Switch filters to view tasks from other categories."
    }

    private func isCategorySelected(_ categoryID: UUID) -> Bool {
        switch store.selectedTaskCategoryFilter {
        case .all:
            return false
        case let .category(selectedID):
            return selectedID == categoryID
        }
    }

    private func countForCategory(_ categoryID: UUID) -> Int {
        store.taskDrafts.filter { draft in
            draft.categories.contains(where: { $0.id == categoryID })
        }
        .count
    }

    private var categoriesWithTasks: [SessionCategoryRecord] {
        store.categories.filter { countForCategory($0.id) > 0 }
    }

    private var sortedFilteredTasks: [AppFeature.State.TaskDraft] {
        sortedTasks(store.filteredTaskDrafts)
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

    private func filterChip(
        title: String,
        count: Int,
        isSelected: Bool,
        tint: Color = .secondary,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            OrbitCategoryChip(
                title: title,
                tint: tint,
                isSelected: isSelected,
                count: count
            )
        }
        .buttonStyle(.plain)
    }

    private func endSessionButtonTapped() {
        isEndSessionConfirmationPending = true
        scheduleEndSessionConfirmationReset()
    }

    private func startSessionButtonTapped() {
        store.send(.startSessionTapped)
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

    private func scheduleEndSessionConfirmationReset() {
        endSessionConfirmationToken += 1
        let token = endSessionConfirmationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard token == endSessionConfirmationToken, isEndSessionConfirmationPending else { return }
            isEndSessionConfirmationPending = false
        }
    }
}

private extension AppFeature.State.TaskDraft {
    var isCompleted: Bool {
        completedAt != nil
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

                Spacer()

                Text("\(session.tasks.count) task\(session.tasks.count == 1 ? "" : "s")")
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

private extension Color {
    init(categoryHex: String) {
        let normalized = FocusDefaults.normalizedCategoryColorHex(categoryHex)
        let hex = String(normalized.dropFirst())
        let value = UInt64(hex, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
