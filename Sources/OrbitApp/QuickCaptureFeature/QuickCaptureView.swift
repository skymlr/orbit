import ComposableArchitecture
import Flow
import Foundation
import SwiftUI

struct QuickCaptureView: View {
    private enum FocusField: Hashable {
        case categoryChip(UUID)
        case priority
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var editorState = MarkdownEditorState()
    @State private var isEditorFocused = false
    @FocusState private var focusedField: FocusField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let activeSession = store.activeSession {
                    Text(activeSession.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if store.captureDraft.editingTaskID != nil {
                    Text("Editing task")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        .transition(.orbitMicro)
                }

                Spacer()

                Button {
                    dismissCapture()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .orbitInteractiveControl(
                    scale: 1.08,
                    lift: -1.0,
                    shadowColor: Color.white.opacity(0.14),
                    shadowRadius: 5
                )
                .foregroundStyle(.secondary)
            }

            if !editorState.isPreviewVisible {
                MarkdownFormattingBar { action in
                    formatActionTapped(action)
                }
                .transition(.orbitMicro)
            }

            Group {
                if editorState.isPreviewVisible {
                    taskPreviewView
                } else {
                    taskEditorView
                }
            }
            .transition(.orbitMicro)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Categories")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        editorState.isPreviewVisible.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Text(editorState.isPreviewVisible ? "Hide Preview" : "Show Preview")
                            shortcutSubtitle("cmd+shift+p")
                        }
                    }
                    .buttonStyle(.orbitQuiet)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }

                HFlow(itemSpacing: 6, rowSpacing: 6) {
                    ForEach(store.categories) { category in
                        categoryChipButton(for: category)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                HStack(spacing: 6) {
                    Text("Priority")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    shortcutSubtitle(store.hotkeys.captureNextPriorityShortcut)
                }

                Picker("Priority", selection: $store.captureDraft.priority) {
                    ForEach(NotePriority.allCases, id: \.self) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .focusable()
                .focused($focusedField, equals: .priority)
                .help("Next Priority \(HotkeyHintFormatter.hint(from: store.hotkeys.captureNextPriorityShortcut))")

                Spacer()
                
                Button {
                    saveButtonTapped()
                } label: {
                    HStack(spacing: 6) {
                        Text(saveButtonTitle)
                        shortcutSubtitle("cmd+return")
                    }
                }
                .buttonStyle(.orbitPrimary)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            editorState.text = store.captureDraft.markdown
            editorState.selectionRange = NSRange(location: (store.captureDraft.markdown as NSString).length, length: 0)
            requestEditorFocus()
        }
        .onChange(of: store.captureDraft.editingTaskID) { _, _ in
            requestEditorFocus()
        }
        .onChange(of: editorState.isPreviewVisible) { _, newValue in
            if !newValue {
                requestEditorFocus()
            } else {
                isEditorFocused = false
            }
        }
        .onChange(of: editorState.text) { _, newValue in
            store.captureDraft.markdown = newValue
        }
        .onChange(of: store.captureDraft.markdown) { _, newValue in
            if newValue != editorState.text {
                editorState.text = newValue
                editorState.selectionRange = NSRange(location: (newValue as NSString).length, length: 0)
            }
        }
        .background(
            ZStack {
                OrbitSpaceBackground()

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .onExitCommand {
            dismissCapture()
        }
        .animation(.easeInOut(duration: 0.16), value: editorState.isPreviewVisible)
        .animation(.easeInOut(duration: 0.16), value: store.captureDraft.editingTaskID != nil)
        .background {
            keyboardShortcutBindings
        }
    }

    private var keyboardShortcutBindings: some View {
        HStack(spacing: 0) {
            Button(action: toggleFocusedCategoryFromKeyboard) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(focusedCategoryID == nil)

            Button(action: cyclePriorityForward) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .orbitKeyboardShortcut(store.hotkeys.captureNextPriorityShortcut)
        }
        .frame(width: 0, height: 0)
        .clipped()
        .opacity(0.001)
    }

    private var taskEditorView: some View {
        ZStack(alignment: .topLeading) {
            MarkdownSourceTextView(
                text: $editorState.text,
                selectionRange: $editorState.selectionRange,
                isFocused: $isEditorFocused,
                onSubmit: {
                    saveButtonTapped()
                },
                onCancel: {
                    dismissCapture()
                },
                onMoveToNextField: {
                    focusCategoryField()
                },
                onMoveToPreviousField: {
                    focusedField = .priority
                }
            )
            .frame(minHeight: 96, maxHeight: 220)

            if editorState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Capture your focus task...")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
            }
        }
    }

    private var taskPreviewView: some View {
        ScrollView {
            if editorState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Nothing to preview yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                MarkdownRenderedTaskView(markdown: editorState.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(minHeight: 96, maxHeight: 220)
    }

    private var canSave: Bool {
        !editorState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var saveButtonTitle: String {
        store.captureDraft.editingTaskID == nil ? "Save Task" : "Save Task Changes"
    }

    @ViewBuilder
    private func shortcutSubtitle(_ shortcut: String) -> some View {
        Text(HotkeyHintFormatter.hint(from: shortcut))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .opacity(0.9)
    }

    private func formatActionTapped(_ action: MarkdownFormatAction) {
        let result = MarkdownEditingCore.apply(
            action: action,
            to: editorState.text,
            selection: editorState.selectionRange
        )
        editorState.text = result.text
        editorState.selectionRange = result.selection
    }

    private func saveButtonTapped() {
        guard canSave else { return }
        store.captureDraft.markdown = editorState.text
        store.send(.captureSubmitTapped)
    }

    private func dismissCapture() {
        store.send(.captureWindowClosed)
    }

    private func focusCategoryField() {
        isEditorFocused = false
        if let firstCategoryID = store.categories.first?.id {
            focusedField = .categoryChip(firstCategoryID)
        } else {
            focusedField = .priority
        }
    }

    private func cyclePriorityForward() {
        let all = NotePriority.allCases
        guard let index = all.firstIndex(of: store.captureDraft.priority) else {
            store.captureDraft.priority = .none
            return
        }

        let next = all[(index + 1) % all.count]
        store.captureDraft.priority = next
    }

    private var focusedCategoryID: UUID? {
        guard case let .categoryChip(categoryID)? = focusedField else { return nil }
        return categoryID
    }

    private func toggleFocusedCategoryFromKeyboard() {
        guard let categoryID = focusedCategoryID else { return }
        toggleCategorySelection(categoryID)
    }

    private func requestEditorFocus() {
        focusedField = nil
        isEditorFocused = false
        DispatchQueue.main.async {
            isEditorFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditorFocused = true
        }
    }

    private func isCategorySelected(_ categoryID: UUID) -> Bool {
        store.captureDraft.selectedCategoryIDs.contains(categoryID)
    }

    private func toggleCategorySelection(_ categoryID: UUID) {
        var selected = store.captureDraft.selectedCategoryIDs
        if let index = selected.firstIndex(of: categoryID) {
            selected.remove(at: index)
        } else {
            selected.append(categoryID)
        }

        store.captureDraft.selectedCategoryIDs = selected
    }

    private func categoryChipButton(for category: SessionCategoryRecord) -> some View {
        let selected = isCategorySelected(category.id)
        let tint = Color(categoryHex: category.colorHex)

        return Button {
            toggleCategorySelection(category.id)
        } label: {
            OrbitCategoryChip(
                title: category.name,
                tint: tint,
                isSelected: selected,
                showsCheckmark: true
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedField, equals: .categoryChip(category.id))
        .help("Toggle \(category.name)")
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
