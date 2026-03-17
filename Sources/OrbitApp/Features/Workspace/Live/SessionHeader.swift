import SwiftUI

struct SessionHeader: View {
    let session: FocusSessionRecord
    let endSessionDraft: AppFeature.State.EndSessionDraft?
    let onRename: (String) -> Void
    let onEndSessionTapped: () -> Void
    let onEndSessionConfirm: (String) -> Void
    let onEndSessionCancel: () -> Void

    @State private var isRenaming = false
    @State private var name = ""
    @State private var isSessionMenuPresented = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if isRenaming {
                    TextField("Session name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .orbitFont(.title2, weight: .bold)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            saveRenaming()
                        }
                        .orbitOnExitCommand {
                            cancelRenaming()
                        }
                } else {
                    Text(session.name)
                        .orbitFont(.largeTitle, weight: .bold)
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

                Button {
                    isSessionMenuPresented = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .orbitFont(.title3, weight: .semibold)
                }
                .buttonStyle(.plain)
                .help("Session management")
                .popover(isPresented: $isSessionMenuPresented, arrowEdge: .bottom) {
                    sessionManagementPopover
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
            .orbitFont(.subheadline)
            .foregroundStyle(.secondary)
        }
        .alert(
            "End Session?",
            isPresented: Binding(
                get: { endSessionDraft != nil },
                set: { isPresented in
                    if !isPresented {
                        onEndSessionCancel()
                    }
                }
            )
        ) {
            Button("End Session", role: .destructive) {
                onEndSessionConfirm(endSessionName)
            }
            Button("Cancel", role: .cancel) {
                onEndSessionCancel()
            }
        } message: {
            Text("This will end the current focus session.")
        }
        .task(id: session.id) {
            name = session.name
            isRenaming = false
            isSessionMenuPresented = false
        }
        .onChange(of: session.name) { _, newValue in
            if !isRenaming {
                name = newValue
            }
        }
    }

    private var sessionManagementPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Rename Session") {
                isSessionMenuPresented = false
                beginRenaming()
            }
            .buttonStyle(.orbitSecondary)

            Button("End Session", role: .destructive) {
                isSessionMenuPresented = false
                onEndSessionTapped()
            }
            .buttonStyle(.orbitDestructive)
        }
        .padding(10)
        .frame(width: 190, alignment: .leading)
    }

    private var endSessionName: String {
        endSessionDraft?.name ?? session.name
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
