import ComposableArchitecture
import Foundation
import SwiftUI

struct QuickCaptureView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var editorState = MarkdownEditorState()
    @State private var isEditorFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let activeSession = store.activeSession {
                Text("\(activeSession.name) • \(activeSession.categoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            MarkdownFormattingBar { action in
                formatActionTapped(action)
            }

            MarkdownSourceTextView(
                text: $editorState.text,
                selectionRange: $editorState.selectionRange,
                isFocused: $isEditorFocused,
                onSubmit: {
                    saveButtonTapped()
                },
                onCancel: {
                    dismissCapture()
                }
            )
            .frame(minHeight: 96, maxHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            )

            Button(editorState.isPreviewVisible ? "Hide Preview" : "Show Preview") {
                editorState.isPreviewVisible.toggle()
            }
            .buttonStyle(.orbitQuiet)

            if editorState.isPreviewVisible {
                ScrollView {
                    Text(MarkdownAttributedRenderer.renderAttributed(markdown: editorState.text))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.thinMaterial)
                )
            }

            TextField("Tags (comma-separated, optional)", text: $store.captureDraft.tags)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    saveButtonTapped()
                }

            HStack {
                Text("Priority")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Priority", selection: $store.captureDraft.priority) {
                    ForEach(NotePriority.allCases, id: \.self) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Save") {
                    saveButtonTapped()
                }
                .buttonStyle(.orbitPrimary)
                .disabled(!canSave)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            editorState.text = store.captureDraft.text
            editorState.selectionRange = NSRange(location: (store.captureDraft.text as NSString).length, length: 0)
            isEditorFocused = true
        }
        .onChange(of: editorState.text) { _, newValue in
            store.captureDraft.text = newValue
        }
        .onChange(of: store.captureDraft.text) { _, newValue in
            if newValue != editorState.text {
                editorState.text = newValue
                editorState.selectionRange = NSRange(location: (newValue as NSString).length, length: 0)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .onExitCommand {
            dismissCapture()
        }
    }

    private var canSave: Bool {
        !editorState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        store.captureDraft.text = editorState.text
        store.send(.captureSubmitTapped)
    }

    private func dismissCapture() {
        store.send(.captureWindowClosed)
    }
}
