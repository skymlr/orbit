import ComposableArchitecture
import SwiftUI

struct FloatingPaletteView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @FocusState private var isNoteFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let activeSession = store.activeSession {
                Text("\(activeSession.name) • \(activeSession.categoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TextField("Capture note text", text: $store.captureDraft.text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2 ... 8)
                .focused($isNoteFieldFocused)
                .onKeyPress(.return, phases: .down) { keyPress in
                    if keyPress.modifiers.contains(.shift) {
                        store.captureDraft.text.append("\n")
                        return .handled
                    }
                    return .ignored
                }
                .onSubmit {
                    saveButtonTapped()
                }

            TextField("Tags (comma-separated, optional)", text: $store.captureDraft.tags)
                .textFieldStyle(.roundedBorder)

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
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(14)
        .frame(width: 360)
        .task {
            isNoteFieldFocused = true
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var canSave: Bool {
        !store.captureDraft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveButtonTapped() {
        guard canSave else { return }
        store.send(.captureSubmitTapped)
    }
}
