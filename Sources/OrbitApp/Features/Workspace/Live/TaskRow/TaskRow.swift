import Foundation
import SwiftUI

struct TaskRow: View {
    @Environment(\.orbitAdaptiveLayout) private var layout
    let draft: AppFeature.State.TaskDraft
    let isKeyboardHighlighted: Bool
    let onKeyboardPopoverDismissed: (() -> Void)?
    let onPrioritySet: (NotePriority) -> Void
    let onToggleCompletion: () -> Void
    let onToggleChecklistLine: (Int) -> Void

    @State private var isPriorityPopoverPresented = false
    @State private var isKeyboardShortcutMenuPresented = false
    @State private var completionAnimationToken = 0
    @State private var completionBurstProgress: CGFloat = 0
    @State private var isCompletionBurstVisible = false

    init(
        draft: AppFeature.State.TaskDraft,
        isKeyboardHighlighted: Bool = false,
        onKeyboardPopoverDismissed: (() -> Void)? = nil,
        onPrioritySet: @escaping (NotePriority) -> Void,
        onToggleCompletion: @escaping () -> Void,
        onToggleChecklistLine: @escaping (Int) -> Void
    ) {
        self.draft = draft
        self.isKeyboardHighlighted = isKeyboardHighlighted
        self.onKeyboardPopoverDismissed = onKeyboardPopoverDismissed
        self.onPrioritySet = onPrioritySet
        self.onToggleCompletion = onToggleCompletion
        self.onToggleChecklistLine = onToggleChecklistLine
    }

    private var isCompleted: Bool {
        draft.completedAt != nil
    }

    var body: some View {
        Group {
            if layout.isCompact {
                taskCard
            } else {
                taskCard
                    .popover(
                        isPresented: $isKeyboardShortcutMenuPresented,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .trailing
                    ) {
                        TaskRowKeyboardShortcutMenu()
                    }
            }
        }
    }

    private var taskCard: some View {
        HStack(alignment: .top, spacing: layout.isCompact ? 12 : 14) {
            completionToggle
                .padding(.leading, layout.isCompact ? 10 : 12)

            VStack(alignment: .leading, spacing: 12) {
                MarkdownRenderedTaskView(
                    markdown: draft.markdown,
                    onTaskLineToggle: onToggleChecklistLine
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .strikethrough(isCompleted, color: .secondary)
                .opacity(isCompleted ? 0.65 : 1)

                taskMetadataSection
            }
            .padding(.trailing, 46)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(layout.isCompact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(taskBackgroundColor(isCompleted: isCompleted))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(taskBorderColor(isCompleted: isCompleted), lineWidth: 1.2)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(priorityRailColor(for: draft.priority, isCompleted: isCompleted))
                .frame(width: 4)
                .padding(.vertical, 5)
                .padding(.leading, 4)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isKeyboardHighlighted ? 1.015 : 1)
        .shadow(
            color: TaskRowPalette.heroCyan.opacity(isKeyboardHighlighted ? 0.17 : 0),
            radius: isKeyboardHighlighted ? 10 : 0,
            x: 0,
            y: 0
        )
        .shadow(
            color: TaskRowPalette.starlight.opacity(isKeyboardHighlighted ? 0.08 : 0),
            radius: isKeyboardHighlighted ? 16 : 0,
            x: 0,
            y: 0
        )
        .animation(.easeInOut(duration: 0.16), value: isKeyboardHighlighted)
        .onChange(of: isCompleted) { oldValue, newValue in
            handleCompletionStateChange(from: oldValue, to: newValue)
        }
        .onChange(of: isKeyboardHighlighted) { _, newValue in
            isKeyboardShortcutMenuPresented = newValue
        }
        .onChange(of: isKeyboardShortcutMenuPresented) { _, newValue in
            if !newValue && isKeyboardHighlighted {
                onKeyboardPopoverDismissed?()
            }
        }
        .task(id: draft.id) {
            resetTransientUIState()
            isKeyboardShortcutMenuPresented = isKeyboardHighlighted
        }
    }

    private var completionToggle: some View {
        Button {
            onToggleCompletion()
        } label: {
            ZStack {
                Circle()
                    .fill(isCompleted ? TaskRowPalette.completedFill : TaskRowPalette.idleFill)

                Circle()
                    .stroke(isCompleted ? TaskRowPalette.completedStroke : TaskRowPalette.idleStroke, lineWidth: isCompleted ? 2.5 : 2.1)

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
                        .shadow(color: TaskRowPalette.completionGreen.opacity(0.75), radius: 6)
                        .symbolEffect(.bounce, value: completionAnimationToken)
                }
            }
            .frame(width: 36, height: 36)
            .overlay {
                completionBurstOverlay
            }
            .scaleEffect(isCompleted ? 1.08 : 1.0)
            .animation(.spring(response: 0.30, dampingFraction: 0.58), value: isCompleted)
        }
        .buttonStyle(.plain)
        .orbitInteractiveControl(
            scale: 1.10,
            lift: -1.0,
            shadowColor: isCompleted ? TaskRowPalette.completionGreen.opacity(0.34) : Color.white.opacity(0.15),
            shadowRadius: 8
        )
        .help(isCompleted ? "Mark task as open" : "Mark task as completed")
    }

    @ViewBuilder
    private var completionBurstOverlay: some View {
        if isCompletionBurstVisible {
            ZStack {
                ForEach(Array(Self.completionBurstVectors.enumerated()), id: \.offset) { index, vector in
                    Circle()
                        .fill(TaskRowPalette.sparkleColors[index % TaskRowPalette.sparkleColors.count])
                        .frame(
                            width: index.isMultiple(of: 3) ? 6 : 4,
                            height: index.isMultiple(of: 3) ? 6 : 4
                        )
                        .offset(
                            x: vector.width * completionBurstProgress,
                            y: vector.height * completionBurstProgress
                        )
                        .scaleEffect(1 + (completionBurstProgress * 0.60))
                        .opacity(1 - completionBurstProgress)
                }
            }
            .frame(width: 58, height: 58)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var taskMetadataSection: some View {
        if layout.isCompact {
            VStack(alignment: .leading, spacing: 6) {
                priorityBadge

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
        } else {
            HStack(alignment: .center, spacing: 8) {
                priorityBadge

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
        }
    }

    private var priorityBadge: some View {
        priorityButton
    }

    private var priorityButton: some View {
        Button {
            isPriorityPopoverPresented = true
        } label: {
            priorityBadgeLabel
        }
        .buttonStyle(.plain)
        .orbitInteractiveControl(
            scale: 1.03,
            lift: -0.5,
            shadowColor: priorityRailColor(for: draft.priority, isCompleted: isCompleted).opacity(0.34),
            shadowRadius: 5
        )
        .accessibilityLabel("Priority")
        .accessibilityValue(draft.priority.title)
        .accessibilityHint("Activate to choose a new priority.")
        .help("Priority: \(draft.priority.title). Click to choose.")
        .modifier(PriorityPickerPresentationModifier(
            isCompact: layout.isCompact,
            isPresented: $isPriorityPopoverPresented,
            popoverContent: priorityPickerPopover,
            currentPriority: draft.priority,
            onPrioritySet: onPrioritySet
        ))
    }

    private var priorityBadgeLabel: some View {
        let fillColor = priorityBadgeFillColor(for: draft.priority, isCompleted: isCompleted)
        let strokeColor = priorityBadgeStrokeColor(for: draft.priority, isCompleted: isCompleted)
        let textColor = priorityBadgeTextColor(for: draft.priority, isCompleted: isCompleted)

        return HStack(spacing: 6) {
            Image(systemName: priorityIcon(for: draft.priority))
                .orbitFont(.caption2, weight: .bold)

            Text(draft.priority.title)
                .lineLimit(1)
        }
        .orbitFont(.caption, weight: .semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(fillColor)
        )
        .overlay(
            Capsule()
                .stroke(strokeColor, lineWidth: 1)
        )
        .foregroundStyle(textColor)
    }

    private var priorityPickerPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set Priority")
                .orbitFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)

            ForEach(NotePriority.allCases, id: \.self) { priority in
                Button {
                    onPrioritySet(priority)
                    isPriorityPopoverPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: priorityIcon(for: priority))
                            .orbitFont(.caption, weight: .bold)
                            .foregroundStyle(priorityAccentColor(for: priority))

                        Text(priority.title)
                            .orbitFont(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 10)

                        if draft.priority == priority {
                            Image(systemName: "checkmark.circle.fill")
                                .orbitFont(.caption, weight: .bold)
                                .foregroundStyle(priorityAccentColor(for: priority))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                draft.priority == priority
                                    ? priorityAccentColor(for: priority).opacity(0.20)
                                    : Color.clear
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                draft.priority == priority
                                    ? priorityAccentColor(for: priority).opacity(0.76)
                                    : Color.white.opacity(0.14),
                                lineWidth: draft.priority == priority ? 1 : 0.6
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set priority to \(priority.title)")
            }
        }
        .padding(10)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
        .orbitOnExitCommand {
            isPriorityPopoverPresented = false
        }
    }

    private func taskBackgroundColor(isCompleted: Bool) -> Color {
        if isCompleted {
            return TaskRowPalette.heroNavy.opacity(0.40)
        }
        return TaskRowPalette.heroNavy.opacity(0.32)
    }

    private func taskBorderColor(isCompleted: Bool) -> Color {
        if isCompleted {
            return TaskRowPalette.completionGreen.opacity(0.82)
        }
        return Color.white.opacity(0.28)
    }

    private func priorityRailColor(for priority: NotePriority, isCompleted: Bool) -> Color {
        let baseColor = priorityAccentColor(for: priority)
        return isCompleted ? baseColor.opacity(0.55) : baseColor
    }

    private func priorityBadgeFillColor(for priority: NotePriority, isCompleted: Bool) -> Color {
        priorityAccentColor(for: priority).opacity(isCompleted ? 0.22 : 0.32)
    }

    private func priorityBadgeStrokeColor(for priority: NotePriority, isCompleted: Bool) -> Color {
        priorityAccentColor(for: priority).opacity(isCompleted ? 0.70 : 0.96)
    }

    private func priorityBadgeTextColor(for priority: NotePriority, isCompleted: Bool) -> Color {
        switch priority {
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

    private func priorityAccentColor(for priority: NotePriority) -> Color {
        switch priority {
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

    private func priorityIcon(for priority: NotePriority) -> String {
        switch priority {
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

    private func resetTransientUIState() {
        isPriorityPopoverPresented = false
        isCompletionBurstVisible = false
        completionBurstProgress = 0
    }

    private func handleCompletionStateChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }

        if !newValue {
            isCompletionBurstVisible = false
            completionBurstProgress = 0
            return
        }

        completionAnimationToken += 1
        completionBurstProgress = 0
        isCompletionBurstVisible = true

        withAnimation(.easeOut(duration: OrbitTheme.Motion.celebration)) {
            completionBurstProgress = 1
        }

        let token = completionAnimationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            guard token == completionAnimationToken else { return }
            isCompletionBurstVisible = false
            completionBurstProgress = 0
        }
    }

    private static let completionBurstVectors: [CGSize] = [
        CGSize(width: 0, height: -22),
        CGSize(width: 16, height: -16),
        CGSize(width: 22, height: 0),
        CGSize(width: 16, height: 16),
        CGSize(width: 0, height: 22),
        CGSize(width: -16, height: 16),
        CGSize(width: -22, height: 0),
        CGSize(width: -16, height: -16),
    ]
}

private struct PriorityPickerPresentationModifier<PopoverContent: View>: ViewModifier {
    let isCompact: Bool
    @Binding var isPresented: Bool
    let popoverContent: PopoverContent
    let currentPriority: NotePriority
    let onPrioritySet: (NotePriority) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isCompact {
            content
                .confirmationDialog(
                    "Set Priority",
                    isPresented: $isPresented,
                    titleVisibility: .visible
                ) {
                    ForEach(NotePriority.allCases, id: \.self) { priority in
                        Button(priorityActionTitle(for: priority)) {
                            onPrioritySet(priority)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
        } else {
            content
                .popover(
                    isPresented: $isPresented,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .bottom
                ) {
                    popoverContent
                }
        }
    }

    private func priorityActionTitle(for priority: NotePriority) -> String {
        if priority == currentPriority {
            return "\(priority.title) Selected"
        }
        return priority.title
    }
}

enum TaskRowPalette {
    static let heroNavy = OrbitTheme.Palette.heroNavy
    static let heroCyan = OrbitTheme.Palette.heroCyan
    static let heroAmber = OrbitTheme.Palette.heroAmber
    static let completionGreen = OrbitTheme.Palette.completionGreen
    static let starlight = OrbitTheme.Palette.starlight
    static let supernovaRed = OrbitTheme.Palette.toastFailure
    static let priorityNone = OrbitTheme.Palette.priorityNone
    static let priorityLow = OrbitTheme.Palette.priorityLow
    static let priorityMedium = OrbitTheme.Palette.priorityMedium
    static let priorityHigh = OrbitTheme.Palette.priorityHigh

    static let completedFill = RadialGradient(
        colors: [
            completionGreen.opacity(0.94),
            heroCyan.opacity(0.82),
            heroNavy.opacity(0.84),
        ],
        center: .center,
        startRadius: 2,
        endRadius: 26
    )

    static let idleFill = RadialGradient(
        colors: [
            starlight.opacity(0.18),
            heroNavy.opacity(0.58),
        ],
        center: .center,
        startRadius: 2,
        endRadius: 24
    )

    static let completedStroke = completionGreen.opacity(0.94)
    static let idleStroke = heroCyan.opacity(0.56)
    static let orbitRing = heroAmber

    static let sparkleColors: [Color] = [
        completionGreen,
        starlight,
        heroCyan,
        heroAmber,
    ]
}

#if DEBUG
private enum TaskRowPreviewFixtures {
    static let previewCreatedAt = Date(timeIntervalSinceReferenceDate: 764_550_000)
    static let previewCompletedAt = previewCreatedAt.addingTimeInterval(900)

    static let designCategory = NoteCategoryRecord(
        id: UUID(uuidString: "2AE18657-B2CA-430E-BFE6-0166B2912E27")!,
        name: "Design",
        colorHex: "#FF9F1C"
    )

    static let engineeringCategory = NoteCategoryRecord(
        id: UUID(uuidString: "C2666C39-E853-414F-BB77-454DA6F0CA5E")!,
        name: "Engineering",
        colorHex: "#00B5FF"
    )

    static let openDraft = AppFeature.State.TaskDraft(
        id: UUID(uuidString: "1C1C3B71-3695-4D45-B4EE-A26972DF7099")!,
        categories: [designCategory, engineeringCategory],
        markdown: """
        ## Preview the task states
        - [ ] Add a live task-row preview
        - [x] Add a history task-row preview
        Tighten the spacing around the segmented control label.
        """,
        priority: .medium,
        completedAt: nil,
        carriedFromTaskID: nil,
        carriedFromSessionName: nil,
        createdAt: previewCreatedAt
    )

    static let completedDraft = AppFeature.State.TaskDraft(
        id: UUID(uuidString: "0DE66CF7-F663-4051-BE35-B59A3EB7F627")!,
        categories: [engineeringCategory],
        markdown: """
        Publish the preview fixtures for the task rows.
        1. Verify the completed state
        2. Verify the keyboard highlight
        """,
        priority: .high,
        completedAt: previewCompletedAt,
        carriedFromTaskID: UUID(uuidString: "6C530111-8E02-4E29-8D29-39AF7494B4F2"),
        carriedFromSessionName: "Preview Cleanup",
        createdAt: previewCreatedAt.addingTimeInterval(-1_500)
    )

    static func toggledChecklistMarkdown(in markdown: String, lineIndex: Int) -> String {
        var lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.indices.contains(lineIndex) else { return markdown }

        if let uncheckedRange = lines[lineIndex].range(of: "[ ]") {
            lines[lineIndex].replaceSubrange(uncheckedRange, with: "[x]")
        } else if let checkedRange = lines[lineIndex].range(of: "[x]")
            ?? lines[lineIndex].range(of: "[X]") {
            lines[lineIndex].replaceSubrange(checkedRange, with: "[ ]")
        }

        return lines.joined(separator: "\n")
    }
}

private struct TaskRowPreviewCard: View {
    @State private var draft: AppFeature.State.TaskDraft
    let isKeyboardHighlighted: Bool

    init(draft: AppFeature.State.TaskDraft, isKeyboardHighlighted: Bool = false) {
        self._draft = State(initialValue: draft)
        self.isKeyboardHighlighted = isKeyboardHighlighted
    }

    var body: some View {
        TaskRow(
            draft: draft,
            isKeyboardHighlighted: isKeyboardHighlighted,
            onPrioritySet: { draft.priority = $0 },
            onToggleCompletion: toggleCompletion,
            onToggleChecklistLine: toggleChecklistLine(at:)
        )
    }

    private func toggleCompletion() {
        draft.completedAt = draft.completedAt == nil
            ? TaskRowPreviewFixtures.previewCompletedAt
            : nil
    }

    private func toggleChecklistLine(at lineIndex: Int) {
        draft.markdown = TaskRowPreviewFixtures.toggledChecklistMarkdown(
            in: draft.markdown,
            lineIndex: lineIndex
        )
    }
}

private struct TaskRowPreviewGallery: View {
    let layout: OrbitAdaptiveLayoutValue
    let galleryWidth: CGFloat

    var body: some View {
        ZStack {
            OrbitSpaceBackground()

            VStack(alignment: .leading, spacing: 18) {
                TaskRowPreviewCard(
                    draft: TaskRowPreviewFixtures.openDraft,
                    isKeyboardHighlighted: true
                )

                TaskRowPreviewCard(draft: TaskRowPreviewFixtures.completedDraft)
            }
            .padding(24)
            .frame(width: galleryWidth, alignment: .leading)
        }
        .frame(width: galleryWidth + 60, height: 360)
        .environment(\.orbitAdaptiveLayout, layout)
    }
}

struct TaskRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TaskRowPreviewGallery(
                layout: .init(style: .regular, availableWidth: 680),
                galleryWidth: 620
            )
            .previewDisplayName("Regular")

            TaskRowPreviewGallery(
                layout: .init(style: .compact, availableWidth: 375),
                galleryWidth: 315
            )
            .previewDisplayName("Compact")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
