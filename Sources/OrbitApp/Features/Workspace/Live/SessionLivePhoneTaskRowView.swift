import SwiftUI

struct SessionLivePhoneTaskRowView: View {
    let draft: AppFeature.State.TaskDraft
    let onEditRequested: () -> Void
    let onPrioritySet: (NotePriority) -> Void
    let onToggleCompletion: () -> Void
    let onToggleChecklistLine: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            completionToggle
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 12) {
                MarkdownRenderedTaskView(
                    markdown: draft.markdown,
                    onTaskLineToggle: onToggleChecklistLine
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .strikethrough(isCompleted, color: .secondary)
                .opacity(isCompleted ? 0.65 : 1)

                metadataSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .orbitSurfaceCard(
            fillStyle: .ultraThinMaterial,
            cornerRadius: OrbitTheme.Radius.card,
            borderColor: taskBorderColor,
            overlayColor: Color.white.opacity(0.02)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(priorityRailColor)
                .frame(width: 4)
                .padding(.vertical, 5)
                .padding(.leading, 4)
                .accessibilityHidden(true)
        }
        .contentShape(RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous))
        .onTapGesture {
            onEditRequested()
        }
    }

    private var isCompleted: Bool {
        draft.completedAt != nil
    }

    private var completionToggle: some View {
        Button {
            onToggleCompletion()
        } label: {
            ZStack {
                Circle()
                    .fill(isCompleted ? TaskRowPalette.completedFill : TaskRowPalette.idleFill)

                Circle()
                    .stroke(
                        isCompleted ? TaskRowPalette.completedStroke : TaskRowPalette.idleStroke,
                        lineWidth: isCompleted ? 2.5 : 2.1
                    )

                Circle()
                    .stroke(
                        TaskRowPalette.orbitRing.opacity(isCompleted ? 0.55 : 0.30),
                        lineWidth: 0.8
                    )
                    .padding(2)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .orbitFont(size: 14, weight: .black, design: .rounded)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "Mark task as open" : "Mark task as completed")
    }

    private var metadataSection: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 8) {
                priorityMenu

                if !draft.categories.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(draft.categories) { category in
                                OrbitCategoryChip(
                                    title: category.name,
                                    tint: Color(orbitHex: category.colorHex),
                                    isSelected: true
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }
            }

// IMPORTANT: this allows the tab view to collapse on scroll down
            Color.clear
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(NotePriority.allCases, id: \.self) { priority in
                Button(priority.title) {
                    onPrioritySet(priority)
                }
            }
        } label: {
            priorityBadge
        }
        .buttonStyle(.plain)
    }

    private var priorityBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: priorityIcon)
                .orbitFont(.caption2, weight: .bold)

            Text(draft.priority.title)
                .lineLimit(1)
        }
        .orbitFont(.caption, weight: .semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(priorityBadgeFillColor)
        )
        .overlay(
            Capsule()
                .stroke(priorityBadgeStrokeColor, lineWidth: 1)
        )
        .foregroundStyle(priorityBadgeTextColor)
    }

    private var priorityIcon: String {
        switch draft.priority {
        case .none:
            return "minus.circle"
        case .low:
            return "arrow.down.circle.fill"
        case .medium:
            return "equal.circle.fill"
        case .high:
            return "exclamationmark.circle.fill"
        }
    }

    private var priorityColor: Color {
        switch draft.priority {
        case .none:
            return TaskRowPalette.priorityNone
        case .low:
            return TaskRowPalette.priorityLow
        case .medium:
            return TaskRowPalette.priorityMedium
        case .high:
            return TaskRowPalette.priorityHigh
        }
    }

    private var taskBorderColor: Color {
        if isCompleted {
            return TaskRowPalette.completionGreen.opacity(0.82)
        }
        return Color.white.opacity(0.28)
    }

    private var priorityRailColor: Color {
        isCompleted ? priorityColor.opacity(0.55) : priorityColor
    }

    private var priorityBadgeFillColor: Color {
        priorityColor.opacity(isCompleted ? 0.22 : 0.32)
    }

    private var priorityBadgeStrokeColor: Color {
        priorityColor.opacity(isCompleted ? 0.70 : 0.96)
    }

    private var priorityBadgeTextColor: Color {
        switch draft.priority {
        case .none:
            return isCompleted ? Color.white.opacity(0.84) : Color.white.opacity(0.96)
        case .low:
            return Color.white.opacity(isCompleted ? 0.84 : 0.98)
        case .medium:
            return Color.white.opacity(isCompleted ? 0.72 : 0.86)
        case .high:
            return Color.white.opacity(isCompleted ? 0.88 : 1.0)
        }
    }
}
