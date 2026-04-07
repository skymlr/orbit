import SwiftUI

struct TaskRowFloatingTools: View {
    @Environment(\.orbitAdaptiveLayout) private var layout
    let draft: AppFeature.State.TaskDraft

    @State private var isTaskInfoPresented = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            infoAction
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var infoAction: some View {
        Button {
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
        .accessibilityLabel("Task information")
    }

    private var taskInfoPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task Information")
                .orbitFont(.subheadline, weight: .semibold)

            taskMetadata
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
}
