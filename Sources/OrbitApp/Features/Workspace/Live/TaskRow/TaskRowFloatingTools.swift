import SwiftUI

struct TaskRowFloatingTools: View {
    let draft: AppFeature.State.TaskDraft
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPending = false
    @State private var deleteConfirmationToken = 0
    @State private var isTaskInfoPopoverPresented = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            infoAction
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var infoAction: some View {
        Button {
            if !isTaskInfoPopoverPresented {
                isDeleteConfirmationPending = false
            }
            isTaskInfoPopoverPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.body.weight(.semibold))
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isTaskInfoPopoverPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            taskInfoPopover
        }
        .orbitInteractiveControl(
            scale: 1.06,
            lift: -1.0,
            shadowColor: TaskRowPalette.heroCyan.opacity(0.24),
            shadowRadius: 6
        )
        .foregroundStyle(.secondary)
        .accessibilityLabel("Task information")
    }

    private var taskInfoPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task Information")
                .font(.subheadline.weight(.semibold))

            Text("Created: \(draft.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)

            if draft.carriedFromTaskID != nil {
                Text("Carried from: \(draft.carriedFromSessionName ?? "Previous session")")
                    .font(.caption)
            }

            Divider()
                .overlay(Color.white.opacity(0.25))

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    isTaskInfoPopoverPresented = false
                    onEdit()
                } label: {
                    Label("Edit Task", systemImage: "pencil")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)

                if isDeleteConfirmationPending {
                    Button("Confirm Deletion", role: .destructive) {
                        isTaskInfoPopoverPresented = false
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
                            .font(.caption.weight(.semibold))
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

    private func scheduleDeleteConfirmationReset() {
        deleteConfirmationToken += 1
        let token = deleteConfirmationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard token == deleteConfirmationToken, isDeleteConfirmationPending else { return }
            isDeleteConfirmationPending = false
        }
    }
}
