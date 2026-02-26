import ComposableArchitecture
import SwiftUI

struct SessionWindowView: View {
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
                        categories: store.categories,
                        categoryColor: categoryColor(for: activeSession.categoryID),
                        onRename: { name in
                            store.send(.sessionRenameTapped(name))
                        },
                        onCategoryChange: { categoryID in
                            store.send(.sessionCategoryChangedTapped(categoryID))
                        }
                    )

                    if store.noteDrafts.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(store.noteDrafts) { draft in
                                NoteEditorRow(
                                    draft: draft,
                                    onSave: { text, tags, priority in
                                        store.send(.sessionNoteSaveTapped(draft.id, text, tags, priority))
                                    },
                                    onDelete: {
                                        store.send(.sessionNoteDeleteTapped(draft.id))
                                    }
                                )
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.thinMaterial)
                                    )
                                }
                            }
                        }
                        .scrollIndicators(.visible)
                    }

                    HStack {
                        Spacer()
                        if isEndSessionConfirmationPending {
                            Button("Confirm End Session", role: .destructive) {
                                store.send(.sessionWindowEndSessionTapped)
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        } else {
                            Button("End Session") {
                                endSessionButtonTapped()
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: Layout.contentMaxWidth, alignment: .leading)
            } else {
                Text("No active session")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: Layout.contentMaxWidth, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(18)
        .frame(minWidth: 880, minHeight: 640)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.send(.sessionAddNoteTapped)
                } label: {
                    Label("Add Note", systemImage: "plus")
                }
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(.thinMaterial, for: .windowToolbar)
        .task(id: store.activeSession?.id) {
            isEndSessionConfirmationPending = false
            endSessionConfirmationToken += 1
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.15),
                    Color(red: 0.05, green: 0.11, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.25)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No notes yet")
                .font(.title3.weight(.semibold))
            Text("Use + to capture your first focus note for this session.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func categoryColor(for categoryID: UUID) -> Color {
        let colorHex = store.categories.first(where: { $0.id == categoryID })?.colorHex
            ?? FocusDefaults.defaultCategoryColorHex
        return Color(categoryHex: colorHex)
    }

    private func endSessionButtonTapped() {
        isEndSessionConfirmationPending = true
        scheduleEndSessionConfirmationReset()
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

private struct SessionHeader: View {
    let session: FocusSessionRecord
    let categories: [SessionCategoryRecord]
    let categoryColor: Color
    let onRename: (String) -> Void
    let onCategoryChange: (UUID) -> Void

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
                        .onTapGesture {
                            beginRenaming()
                        }
                }

                Spacer(minLength: 10)

                if isRenaming {
                    Button("Save") {
                        saveRenaming()
                    }
                    .buttonStyle(.bordered)
                    .disabled(trimmedName.isEmpty)
                }
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(categories) { category in
                        Button {
                            onCategoryChange(category.id)
                        } label: {
                            if category.id == session.categoryID {
                                Label(category.name, systemImage: "checkmark")
                            } else {
                                Text(category.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(session.categoryName.uppercased())
                            .font(.caption.weight(.bold))
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(categoryColor.opacity(0.28))
                    )
                    .overlay(
                        Capsule()
                            .stroke(categoryColor.opacity(0.95), lineWidth: 1.25)
                    )
                }
                .buttonStyle(.plain)
                .disabled(categories.isEmpty)

                Text("•")
                Text("Started \(session.startedAt, style: .time)")
                Text("•")
                Text("Elapsed \(session.startedAt, style: .timer)")
                
                Spacer()
                
                Text("\(session.notes.count) note\(session.notes.count == 1 ? "" : "s")")
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

private struct NoteEditorRow: View {
    let draft: AppFeature.State.NoteDraft
    let onSave: (String, [String], NotePriority) -> Void
    let onDelete: () -> Void

    @State private var isEditingText = false
    @State private var isAddingTag = false
    @State private var isDeleteConfirmationPending = false
    @State private var deleteConfirmationToken = 0
    @State private var text: String
    @State private var tags: [String]
    @State private var pendingTag = ""
    @State private var priority: NotePriority
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isTagFieldFocused: Bool

    init(
        draft: AppFeature.State.NoteDraft,
        onSave: @escaping (String, [String], NotePriority) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.draft = draft
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: draft.text)
        _tags = State(initialValue: draft.tags)
        _priority = State(initialValue: draft.priority)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(draft.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.headline.weight(.semibold))

                Spacer()

                if isEditingText {
                    Button("Save") {
                        saveTextEditing()
                    }
                    .buttonStyle(.bordered)
                    .disabled(trimmedText.isEmpty)
                }

                if isDeleteConfirmationPending {
                    Button("Confirm Deletion", role: .destructive) {
                        onDelete()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.caption.weight(.semibold))
                } else {
                    Button {
                        isDeleteConfirmationPending = true
                        scheduleDeleteConfirmationReset()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Delete note")
                }
            }

            if isEditingText {
                TextField("Note text", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2 ... 6)
                    .focused($isTextFieldFocused)
                    .onKeyPress(.return, phases: .down) { keyPress in
                        if keyPress.modifiers.contains(.shift) {
                            text.append("\n")
                            return .handled
                        }
                        return .ignored
                    }
                    .onSubmit {
                        saveTextEditing()
                    }
                    .onExitCommand {
                        cancelTextEditing()
                    }
            } else {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture {
                        beginTextEditing()
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(NotePriority.allCases, id: \.self) { item in
                                Button {
                                    prioritySelected(item)
                                } label: {
                                    if item == priority {
                                        Label(item.title, systemImage: "checkmark")
                                    } else {
                                        Text(item.title)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(priority.title.uppercased())
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(priorityColor(for: priority).opacity(0.2))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(priorityColor(for: priority).opacity(0.7), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change priority")
                        
                        if tags.isEmpty {
                            Text("No tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(tags, id: \.self) { tag in
                            TagChip(tag: tag) {
                                removeTag(tag)
                            }
                        }
                        
                        Button {
                            addTagButtonTapped()
                        } label: {
                            Image(systemName: isAddingTag ? "xmark.circle.fill" : "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                if isAddingTag {
                    HStack(spacing: 8) {
                        TextField("New tag", text: $pendingTag)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTagFieldFocused)
                            .onSubmit {
                                addTag()
                            }

                        Button("Add") {
                            addTag()
                        }
                        .buttonStyle(.bordered)
                        .disabled(trimmedPendingTag.isEmpty)
                    }
                }
            }
        }
        .task(id: draft) {
            if !isEditingText {
                text = draft.text
                priority = draft.priority
            }
            tags = draft.tags
            isDeleteConfirmationPending = false
            deleteConfirmationToken += 1
        }
    }

    private func priorityColor(for priority: NotePriority) -> Color {
        switch priority {
        case .none:
            return .gray
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPendingTag: String {
        pendingTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginTextEditing() {
        isEditingText = true
        DispatchQueue.main.async {
            isTextFieldFocused = true
        }
    }

    private func saveTextEditing() {
        guard !trimmedText.isEmpty else { return }
        persistChanges()
        isEditingText = false
    }

    private func cancelTextEditing() {
        text = draft.text
        isEditingText = false
    }

    private func prioritySelected(_ newPriority: NotePriority) {
        guard priority != newPriority else { return }
        priority = newPriority
        persistChanges()
    }

    private func addTag() {
        let normalizedTag = FocusDefaults.normalizedTag(trimmedPendingTag)
        guard !normalizedTag.isEmpty else { return }
        guard !tags.contains(where: { FocusDefaults.normalizedTag($0) == normalizedTag }) else {
            pendingTag = ""
            return
        }

        tags.append(normalizedTag)
        pendingTag = ""
        isAddingTag = false
        isTagFieldFocused = false
        persistChanges()
    }

    private func addTagButtonTapped() {
        if isAddingTag {
            pendingTag = ""
            isAddingTag = false
            isTagFieldFocused = false
        } else {
            isAddingTag = true
            DispatchQueue.main.async {
                isTagFieldFocused = true
            }
        }
    }

    private func removeTag(_ tag: String) {
        tags.removeAll(where: { FocusDefaults.normalizedTag($0) == FocusDefaults.normalizedTag(tag) })
        persistChanges()
    }

    private func persistChanges() {
        guard !trimmedText.isEmpty else { return }
        text = trimmedText
        onSave(trimmedText, tags, priority)
    }

    private func scheduleDeleteConfirmationReset() {
        deleteConfirmationToken += 1
        let token = deleteConfirmationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard token == deleteConfirmationToken, isDeleteConfirmationPending else { return }
            isDeleteConfirmationPending = false
        }
    }
}

private struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
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
