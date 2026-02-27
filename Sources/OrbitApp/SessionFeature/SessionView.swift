import ComposableArchitecture
import Foundation
import AppKit
import SwiftUI

struct SessionView: View {
    private enum Layout {
        static let contentMaxWidth: CGFloat = 700
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.openWindow) private var openWindow
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

                    notesContent
                    endSessionControl
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
                    Image(systemName: "plus")
                }
                .help("Capture Note \(HotkeyHintFormatter.hint(from: store.hotkeys.captureShortcut))")

                Button {
                    openSettingsWindow()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Open Settings")
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
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No notes yet")
                .font(.title3.weight(.semibold))
            HStack(spacing: 6) {
                Text("Use + or")
                HotkeyHintLabel(shortcut: store.hotkeys.captureShortcut)
                Text("to capture your first focus note for this session.")
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

    @ViewBuilder
    private var notesContent: some View {
        if store.noteDrafts.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.noteDrafts) { draft in
                        noteRow(for: draft)
                    }
                }
            }
            .scrollIndicators(.visible)
        }
    }

    private var endSessionControl: some View {
        HStack {
            Spacer()
            if isEndSessionConfirmationPending {
                Button("Confirm End Session", role: .destructive) {
                    store.send(.sessionWindowEndSessionTapped)
                }
                .buttonStyle(.orbitDestructive)
            } else {
                Button("End Session") {
                    endSessionButtonTapped()
                }
                .buttonStyle(.orbitQuiet)
            }
        }
        .padding(.top, 2)
    }

    private func noteRow(for draft: AppFeature.State.NoteDraft) -> some View {
        NoteEditorRow(
            draft: draft,
            onEdit: {
                store.send(.sessionNoteEditTapped(draft.id))
            },
            onToggleTask: { lineIndex in
                store.send(.sessionNoteTaskToggleTapped(draft.id, lineIndex))
            },
            onDelete: {
                store.send(.sessionNoteDeleteTapped(draft.id))
            }
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

    private func openSettingsWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "settings-window")

        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Orbit Settings" }) else {
                return
            }
            window.orderFrontRegardless()
            window.makeKey()
        }
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
                    .buttonStyle(.orbitSecondary)
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
    let onEdit: () -> Void
    let onToggleTask: (Int) -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPending = false
    @State private var deleteConfirmationToken = 0

    init(
        draft: AppFeature.State.NoteDraft,
        onEdit: @escaping () -> Void,
        onToggleTask: @escaping (Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.draft = draft
        self.onEdit = onEdit
        self.onToggleTask = onToggleTask
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MarkdownRenderedNoteView(
                markdown: draft.text,
                onToggleTask: onToggleTask
            )
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)

            tagsSection

            HStack(alignment: .center, spacing: 10) {
                Text(draft.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Edit note")
                .help("Edit note")

                deleteAction
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(noteBackgroundColor(for: draft.priority))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(noteBorderColor(for: draft.priority), lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: draft.id) {
            resetDeleteConfirmation()
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !draft.tags.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(draft.tags, id: \.self) { tag in
                        ReadOnlyTagChip(tag: tag)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var deleteAction: some View {
        if isDeleteConfirmationPending {
            Button("Confirm Deletion", role: .destructive) {
                onDelete()
            }
            .buttonStyle(.orbitDestructive)
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

    private func noteBackgroundColor(for priority: NotePriority) -> Color {
        switch priority {
        case .none:
            return Color.gray.opacity(0.05)
        case .low:
            return Color.blue.opacity(0.08)
        case .medium:
            return Color.orange.opacity(0.09)
        case .high:
            return Color.red.opacity(0.10)
        }
    }

    private func noteBorderColor(for priority: NotePriority) -> Color {
        switch priority {
        case .none:
            return Color.gray.opacity(0.32)
        case .low:
            return Color.blue.opacity(0.55)
        case .medium:
            return Color.orange.opacity(0.60)
        case .high:
            return Color.red.opacity(0.62)
        }
    }

    private func resetDeleteConfirmation() {
        isDeleteConfirmationPending = false
        deleteConfirmationToken += 1
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

private struct ReadOnlyTagChip: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .foregroundStyle(.secondary)
    }
}

private struct MarkdownRenderedNoteView: View {
    let markdown: String
    let onToggleTask: (Int) -> Void

    var body: some View {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let taskLines = MarkdownEditingCore.taskLines(in: markdown)
        let tasksByLine = Dictionary(uniqueKeysWithValues: taskLines.map { ($0.lineIndex, $0) })

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { offset, line in
                lineView(line: line, lineIndex: offset, task: tasksByLine[offset])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lineView(line: String, lineIndex: Int, task: MarkdownTaskLine?) -> some View {
        if let task {
            taskLineRow(task)
        } else if let heading = parseHeadingLine(line) {
            headingLineRow(heading)
        } else if let unordered = parseUnorderedListLine(line) {
            listLineRow(
                marker: "•",
                text: unordered.text,
                indentation: unordered.indentation
            )
        } else if let ordered = parseOrderedListLine(line) {
            listLineRow(
                marker: "\(ordered.number).",
                text: ordered.text,
                indentation: ordered.indentation
            )
        } else if line.isEmpty {
            Text(" ")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(MarkdownAttributedRenderer.renderAttributed(markdown: line))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func headingLineRow(_ heading: HeadingLine) -> some View {
        Text(MarkdownAttributedRenderer.renderAttributed(markdown: heading.text.isEmpty ? " " : heading.text))
            .font(font(for: heading.level))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, indentationWidth(for: heading.indentation))
    }

    @ViewBuilder
    private func listLineRow(marker: String, text: String, indentation: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(MarkdownAttributedRenderer.renderAttributed(markdown: text.isEmpty ? " " : text))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, indentationWidth(for: indentation))
    }

    @ViewBuilder
    private func taskLineRow(_ task: MarkdownTaskLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                onToggleTask(task.lineIndex)
            } label: {
                Image(systemName: task.isChecked ? "checkmark.square.fill" : "square")
            }
            .buttonStyle(.plain)
            .foregroundStyle(task.isChecked ? .green : .secondary)

            Text(MarkdownAttributedRenderer.renderAttributed(markdown: task.lineText.isEmpty ? " " : task.lineText))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, indentationWidth(for: task.indentation))
    }

    private func indentationWidth(for indentation: String) -> CGFloat {
        let columns = indentation.reduce(0) { partialResult, character in
            partialResult + (character == "\t" ? 4 : 1)
        }
        return CGFloat(columns) * 6
    }

    private func font(for headingLevel: Int) -> Font {
        switch headingLevel {
        case 1:
            return .title3.weight(.bold)
        case 2:
            return .headline.weight(.semibold)
        default:
            return .subheadline.weight(.semibold)
        }
    }

    private func parseHeadingLine(_ line: String) -> HeadingLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.headingRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let marker = substring(line, match.range(at: 2)),
              let text = substring(line, match.range(at: 3))
        else {
            return nil
        }

        return HeadingLine(
            level: min(max(marker.count, 1), 6),
            indentation: indentation,
            text: text
        )
    }

    private func parseUnorderedListLine(_ line: String) -> ListLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.unorderedListRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let text = substring(line, match.range(at: 3))
        else {
            return nil
        }

        return ListLine(indentation: indentation, text: text)
    }

    private func parseOrderedListLine(_ line: String) -> OrderedListLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.orderedListRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let number = substring(line, match.range(at: 2)),
              let text = substring(line, match.range(at: 4))
        else {
            return nil
        }

        return OrderedListLine(indentation: indentation, number: number, text: text)
    }

    private func substring(_ line: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound else { return nil }
        guard let swiftRange = Range(range, in: line) else { return nil }
        return String(line[swiftRange])
    }

    private struct HeadingLine {
        let level: Int
        let indentation: String
        let text: String
    }

    private struct ListLine {
        let indentation: String
        let text: String
    }

    private struct OrderedListLine {
        let indentation: String
        let number: String
        let text: String
    }

    private static let headingRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)(#{1,6})\s+(.*)$"#
    )

    private static let unorderedListRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+])\s+(.*)$"#
    )

    private static let orderedListRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)(\d+)([.)])\s+(.*)$"#
    )
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
