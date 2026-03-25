import ComposableArchitecture
import Flow
import Foundation
import SwiftUI

struct QuickCaptureView: View {
    private enum FocusField: Hashable {
        case newCategoryName
        case categoryChip(UUID)
        case priority
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.orbitAppearance) private var appearance
    @State private var editorState = MarkdownEditorState()
    @State private var isEditorFocused = false
    @State private var isAddingFirstCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = FocusDefaults.defaultCategoryColorHex
    @State private var pendingCreatedCategoryNormalizedName: String?
    @FocusState private var focusedField: FocusField?

    var body: some View {
        OrbitAdaptiveLayoutReader { layout in
            captureContent(for: layout)
                .task {
                    editorState.text = store.captureDraft.markdown
                    editorState.selectionRange = NSRange(location: (store.captureDraft.markdown as NSString).length, length: 0)
                    requestEditorFocus()
                }
                .onChange(of: store.captureDraft.editingTaskID) { _, _ in
                    requestEditorFocus()
                }
                .onChange(of: store.presentation.capturePresentationRequest) { _, _ in
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
                .onChange(of: store.categories) { _, categories in
                    categoriesChanged(categories)
                }
                .background {
                    captureBackground(for: layout)
                }
                .orbitOnExitCommand {
                    dismissCapture()
                }
                .animation(.easeInOut(duration: OrbitTheme.Motion.micro), value: editorState.isPreviewVisible)
                .animation(.easeInOut(duration: OrbitTheme.Motion.micro), value: store.captureDraft.editingTaskID != nil)
                .background {
                    keyboardShortcutBindings
                }
        }
    }

    @ViewBuilder
    private func captureContent(for layout: OrbitAdaptiveLayoutValue) -> some View {
        if layout.isCompact {
            compactCaptureContent(for: layout)
        } else {
            regularCaptureContent(for: layout)
        }
    }

    private func regularCaptureContent(for layout: OrbitAdaptiveLayoutValue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            captureHeader
            editorSection
            categorySection(for: layout)
            actionArea(for: layout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func compactCaptureContent(for layout: OrbitAdaptiveLayoutValue) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                captureHeader
                editorSection
                categorySection(for: layout)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .orbitInteractiveKeyboardDismiss()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            compactActionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func captureBackground(for layout: OrbitAdaptiveLayoutValue) -> some View {
        if layout.isCompact {
            OrbitSpaceBackground()
        } else {
            ZStack {
                OrbitSpaceBackground()

                RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.32))
                    .blur(radius: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous))
        }
    }

    private var captureHeader: some View {
        HStack {
            if let activeSession = store.activeSession {
                Text(activeSession.name)
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if store.captureDraft.editingTaskID != nil {
                Text("Editing task")
                    .orbitFont(.caption2, weight: .semibold)
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
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.small, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    private func categorySection(for layout: OrbitAdaptiveLayoutValue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Categories")
                    .orbitFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    editorState.isPreviewVisible.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(editorState.isPreviewVisible ? "Hide Preview" : "Show Preview")
                        shortcutSubtitle("cmd+shift+p", isVisible: !layout.isCompact)
                    }
                }
                .buttonStyle(.orbitQuiet)
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            categorySectionContent
        }
    }

    private func actionArea(for layout: OrbitAdaptiveLayoutValue) -> some View {
        HStack {
            HStack(spacing: 6) {
                Text("Priority")
                    .orbitFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                shortcutSubtitle(store.hotkeys.captureNextPriorityShortcut, isVisible: !layout.isCompact)
            }

            priorityPicker

            Spacer()

            Button {
                saveButtonTapped()
            } label: {
                HStack(spacing: 6) {
                    Text(saveButtonTitle)
                    shortcutSubtitle("cmd+return", isVisible: !layout.isCompact)
                }
            }
            .buttonStyle(.orbitPrimary)
            .disabled(!canSave)
            .keyboardShortcut(.return, modifiers: [.command])
        }
    }

    private var compactActionBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Priority")
                    .orbitFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                priorityPicker
            }

            Button {
                saveButtonTapped()
            } label: {
                Text(saveButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.orbitPrimary)
            .disabled(!canSave)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
    }

    private var priorityPicker: some View {
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
                appearance: appearance,
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
            .frame(minHeight: 96, idealHeight: 140, maxHeight: 220)

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
                    .orbitFont(.caption)
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

    private var canSubmitNewCategory: Bool {
        !trimmedNewCategoryName.isEmpty
    }

    private var saveButtonTitle: String {
        store.captureDraft.editingTaskID == nil ? "Save Task" : "Save Task Changes"
    }

    private var trimmedNewCategoryName: String {
        newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var categorySectionContent: some View {
        if store.categories.isEmpty {
            emptyCategoryState
        } else {
            HFlow(itemSpacing: 6, rowSpacing: 6) {
                ForEach(store.categories) { category in
                    categoryChipButton(for: category)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyCategoryState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No categories yet. Add your first category to start organizing captured tasks.")
                .orbitFont(.caption)
                .foregroundStyle(.secondary)

            if isAddingFirstCategory {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Category name", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .newCategoryName)
                        .onSubmit {
                            submitNewCategoryButtonTapped()
                        }

                    CategoryColorPalettePicker(selectedHex: $newCategoryColorHex)

                    HStack {
                        Button("Cancel") {
                            cancelNewCategoryButtonTapped()
                        }
                        .buttonStyle(.orbitSecondary)

                        Spacer()

                        Button("Add Category") {
                            submitNewCategoryButtonTapped()
                        }
                        .buttonStyle(.orbitPrimary)
                        .disabled(!canSubmitNewCategory)
                    }
                }
            } else {
                Button {
                    addFirstCategoryButtonTapped()
                } label: {
                    Label("Add Category", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.orbitPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.small, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    @ViewBuilder
    private func shortcutSubtitle(_ shortcut: String, isVisible: Bool = true) -> some View {
        if isVisible {
            Text(HotkeyHintFormatter.hint(from: shortcut))
                .orbitFont(.caption2)
                .foregroundStyle(.tertiary)
                .opacity(0.9)
        }
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
        } else if isAddingFirstCategory {
            focusedField = .newCategoryName
        } else {
            focusedField = .priority
        }
    }

    private func addFirstCategoryButtonTapped() {
        isAddingFirstCategory = true
        DispatchQueue.main.async {
            focusedField = .newCategoryName
        }
    }

    private func cancelNewCategoryButtonTapped() {
        resetInlineCategoryForm(clearPendingCategory: true)
    }

    private func submitNewCategoryButtonTapped() {
        guard canSubmitNewCategory else { return }
        pendingCreatedCategoryNormalizedName = FocusDefaults.normalizedCategoryName(trimmedNewCategoryName)
        store.send(.settingsAddCategoryTapped(trimmedNewCategoryName, newCategoryColorHex))
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

    private func categoriesChanged(_ categories: [SessionCategoryRecord]) {
        if let pendingCreatedCategoryNormalizedName,
           let createdCategory = categories.first(where: { $0.normalizedName == pendingCreatedCategoryNormalizedName })
        {
            if !store.captureDraft.selectedCategoryIDs.contains(createdCategory.id) {
                store.captureDraft.selectedCategoryIDs.append(createdCategory.id)
            }
            resetInlineCategoryForm(clearPendingCategory: true)
            return
        }

        guard !categories.isEmpty else { return }
        resetInlineCategoryForm(clearPendingCategory: false)
    }

    private func resetInlineCategoryForm(clearPendingCategory: Bool) {
        isAddingFirstCategory = false
        newCategoryName = ""
        newCategoryColorHex = FocusDefaults.defaultCategoryColorHex
        if clearPendingCategory {
            pendingCreatedCategoryNormalizedName = nil
        }
        if focusedField == .newCategoryName {
            focusedField = nil
        }
    }

    private func categoryChipButton(for category: SessionCategoryRecord) -> some View {
        let selected = isCategorySelected(category.id)
        let tint = Color(orbitHex: category.colorHex)

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
