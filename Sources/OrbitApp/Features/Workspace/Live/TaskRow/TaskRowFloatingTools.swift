import SwiftUI

struct TaskRowFloatingTools: View {
    @Environment(\.orbitAdaptiveLayout) private var layout
    let draft: AppFeature.State.TaskDraft
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPending = false
    @State private var deleteConfirmationToken = 0
    @State private var isTaskInfoPresented = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            infoAction
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var infoAction: some View {
        Button {
            if !isTaskInfoPresented {
                isDeleteConfirmationPending = false
            }
            isTaskInfoPresented.toggle()
        } label: {
            Image(systemName: layout.isCompact ? "ellipsis.circle" : "info.circle")
                .orbitFont(.body, weight: .semibold)
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isTaskInfoPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            taskInfoPopover
#if os(iOS)
                .presentationCompactAdaptation(.popover)
#endif
        }
        .orbitInteractiveControl(
            scale: 1.06,
            lift: -1.0,
            shadowColor: TaskRowPalette.heroCyan.opacity(0.24),
            shadowRadius: 6
        )
        .foregroundStyle(.secondary)
        .accessibilityLabel(layout.isCompact ? "Task actions" : "Task information")
    }

    private var taskInfoPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task Information")
                .orbitFont(.subheadline, weight: .semibold)

            taskMetadata

            Divider()
                .overlay(Color.white.opacity(0.25))

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    isTaskInfoPresented = false
                    onEdit()
                } label: {
                    Label("Edit Task", systemImage: "pencil")
                        .labelStyle(.titleAndIcon)
                        .orbitFont(.caption, weight: .semibold)
                }
                .buttonStyle(.plain)

                if isDeleteConfirmationPending {
                    Button("Confirm Deletion", role: .destructive) {
                        isTaskInfoPresented = false
                        onDelete()
                    }
                    .buttonStyle(.orbitDestructive)
                } else {
                    Button(role: .destructive) {
                        isDeleteConfirmationPending = true
                        scheduleDeleteConfirmationReset()
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                            .labelStyle(.titleAndIcon)
                            .orbitFont(.caption, weight: .semibold)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white.opacity(0.92))
        .frame(minWidth: 220, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OrbitTheme.Gradients.taskInfoPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskRowPalette.heroCyan.opacity(0.48), lineWidth: 1)
        )
    }

    private var taskMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Created: \(draft.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .orbitFont(.caption)

            if draft.carriedFromTaskID != nil {
                Text("Carried from: \(draft.carriedFromSessionName ?? "Previous session")")
                    .orbitFont(.caption)
            }
        }
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
