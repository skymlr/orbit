import ComposableArchitecture
import SwiftUI

struct SessionWindowView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let activeSession = store.activeSession {
                header(activeSession)

                HStack {
                    Button("Add Note") {
                        store.send(.sessionAddNoteTapped)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("End Session") {
                        store.send(.endSessionTapped)
                    }
                }

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
                                .id(noteRowIdentity(for: draft))
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
            } else {
                Text("No active session")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(minWidth: 880, minHeight: 640)
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

    @ViewBuilder
    private func header(_ activeSession: FocusSessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activeSession.name)
                .font(.largeTitle.weight(.bold))

            HStack(spacing: 8) {
                Text("Category: \(activeSession.categoryName)")
                Text("•")
                Text("Started \(activeSession.startedAt, style: .time)")
                Text("•")
                Text("Elapsed \(activeSession.startedAt, style: .timer)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No notes yet")
                .font(.title3.weight(.semibold))
            Text("Use Add Note to capture your first focus note for this session.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func noteRowIdentity(for draft: AppFeature.State.NoteDraft) -> String {
        [
            draft.id.uuidString,
            draft.text,
            draft.tags,
            draft.priority.rawValue,
        ].joined(separator: "|")
    }
}

private struct NoteEditorRow: View {
    let draft: AppFeature.State.NoteDraft
    let onSave: (String, String, NotePriority) -> Void
    let onDelete: () -> Void

    @State private var text: String
    @State private var tags: String
    @State private var priority: NotePriority

    init(
        draft: AppFeature.State.NoteDraft,
        onSave: @escaping (String, String, NotePriority) -> Void,
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
                Text(priority.title)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(for: priority).opacity(0.2))
                    .clipShape(Capsule())

                Spacer()

                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }

            TextField("Note text", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2 ... 6)

            TextField("Tags (comma-separated)", text: $tags)
                .textFieldStyle(.roundedBorder)

            Picker("Priority", selection: $priority) {
                ForEach(NotePriority.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Save") {
                    onSave(text, tags, priority)
                }
                .buttonStyle(.bordered)
            }
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
}
