import Foundation
import SwiftUI

struct HistorySessionStripView: View {
    @Environment(\.orbitAdaptiveLayout) private var layout
    let sessions: [FocusSessionRecord]
    let selectedSessionID: UUID?
    let onSelect: (UUID) -> Void
    let onRename: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onExport: (UUID) -> Void

    @State private var menuSessionID: UUID?
    @State private var menuMode: MenuMode = .actions
    @State private var renameDraft = ""
    @State private var renameSessionID: UUID?
    @State private var deleteConfirmationSessionID: UUID?

    private enum MenuMode {
        case actions
        case rename
    }

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
        .confirmationDialog(
            "Delete Session?",
            isPresented: $deleteConfirmationSessionID.isPresented
        ) {
            if let session = sessions.first(where: { $0.id == deleteConfirmationSessionID }) {
                Button("Delete \"\(session.name)\"", role: .destructive) {
                    onDelete(session.id)
                    deleteConfirmationSessionID = nil
                }
            } else {
                Button("Delete Session", role: .destructive) {
                    if let sessionID = deleteConfirmationSessionID {
                        onDelete(sessionID)
                    }
                    deleteConfirmationSessionID = nil
                }
            }

            Button("Cancel", role: .cancel) {
                deleteConfirmationSessionID = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Session Actions",
            isPresented: compactMenuBinding,
            titleVisibility: .visible
        ) {
            if let session = currentMenuSession {
                Button("Rename") {
                    renameDraft = session.name
                    renameSessionID = session.id
                    closeMenu()
                }

                Button("Export") {
                    onExport(session.id)
                    closeMenu()
                }

                Button("Delete Session", role: .destructive) {
                    deleteConfirmationSessionID = session.id
                    closeMenu()
                }
            }

            Button("Cancel", role: .cancel) {
                closeMenu()
            }
        }
        .sheet(isPresented: $renameSessionID.isPresented) {
            if let session = currentRenameSession {
                NavigationStack {
                    renameSheet(for: session)
                        .navigationTitle("Rename Session")
                        .orbitInlineNavigationTitleDisplayMode()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    renameSessionID = nil
                                }
                            }

                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    saveRename(for: session.id)
                                }
                                .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                }
                .presentationDetents([.height(240)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var compactMenuBinding: Binding<Bool> {
        Binding(
            get: {
                layout.isCompact && menuSessionID != nil
            },
            set: { isPresented in
                if !isPresented {
                    closeMenu()
                }
            }
        )
    }

    private var currentMenuSession: FocusSessionRecord? {
        sessions.first(where: { $0.id == menuSessionID })
    }

    private var currentRenameSession: FocusSessionRecord? {
        sessions.first(where: { $0.id == renameSessionID })
    }

    private func sessionButton(for session: FocusSessionRecord) -> some View {
        let isSelected = session.id == selectedSessionID
        let taskCountLabel = "\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")"

        return ZStack(alignment: .topTrailing) {
            Button {
                onSelect(session.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .orbitFont(.caption, weight: .semibold)
                        .lineLimit(1)

                    Text("Started \(session.startedAt, style: .time)")
                        .orbitFont(.caption2)
                        .foregroundStyle(.secondary)

                    Text(taskCountLabel)
                        .orbitFont(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .padding(.trailing, 24)
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

            if layout.isCompact {
                Button {
                    menuSessionID = session.id
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .orbitFont(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    menuSessionID = session.id
                    menuMode = .actions
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .orbitFont(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .popover(
                    isPresented: $menuSessionID[isPresenting: session.id],
                    arrowEdge: .top
                ) {
                    sessionMenuPopover(for: session)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionMenuPopover(for session: FocusSessionRecord) -> some View {
        switch menuMode {
        case .actions:
            VStack(alignment: .leading, spacing: 8) {
                Button("Rename") {
                    renameDraft = session.name
                    menuMode = .rename
                }
                .buttonStyle(.orbitSecondary)

                Button("Export") {
                    onExport(session.id)
                    closeMenu()
                }
                .buttonStyle(.orbitSecondary)

                Button("Delete", role: .destructive) {
                    deleteConfirmationSessionID = session.id
                    closeMenu()
                }
                .buttonStyle(.orbitDestructive)
            }
            .padding(10)
            .frame(width: 170, alignment: .leading)

        case .rename:
            VStack(alignment: .leading, spacing: 8) {
                Text("Rename Session")
                    .orbitFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)

                TextField("Session name", text: $renameDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveRename(for: session.id)
                    }

                HStack {
                    Button("Cancel") {
                        menuMode = .actions
                    }
                    .buttonStyle(.orbitSecondary)

                    Spacer()

                    Button("Save") {
                        saveRename(for: session.id)
                    }
                    .buttonStyle(.orbitPrimary)
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(10)
            .frame(width: 240, alignment: .leading)
        }
    }

    private func renameSheet(for session: FocusSessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Update the title used for this archived session.")
                .orbitFont(.caption)
                .foregroundStyle(.secondary)

            TextField("Session name", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    saveRename(for: session.id)
                }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(OrbitSpaceBackground())
    }

    private func saveRename(for sessionID: UUID) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRename(sessionID, trimmed)
        renameSessionID = nil
        closeMenu()
    }

    private func closeMenu() {
        menuSessionID = nil
        menuMode = .actions
    }
}

private extension Optional {
    var isPresented: Bool {
        get { self != nil }
        set {
            guard !newValue else { return }
            self = nil
        }
    }
}

private extension Optional where Wrapped: Equatable {
    subscript(isPresenting value: Wrapped) -> Bool {
        get { self == value }
        set {
            guard !newValue else { return }
            if self == value {
                self = nil
            }
        }
    }
}
