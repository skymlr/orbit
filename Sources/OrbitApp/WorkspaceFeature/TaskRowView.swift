import Foundation
import SwiftUI

struct TaskRow: View {
    let draft: AppFeature.State.TaskDraft
    let onEdit: () -> Void
    let onPrioritySet: (NotePriority) -> Void
    let onToggleCompletion: () -> Void
    let onToggleChecklistLine: (Int) -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPending = false
    @State private var deleteConfirmationToken = 0
    @State private var isTaskInfoPopoverPresented = false
    @State private var isPriorityPopoverPresented = false
    @State private var completionAnimationToken = 0
    @State private var completionBurstProgress: CGFloat = 0
    @State private var isCompletionBurstVisible = false

    init(
        draft: AppFeature.State.TaskDraft,
        onEdit: @escaping () -> Void,
        onPrioritySet: @escaping (NotePriority) -> Void,
        onToggleCompletion: @escaping () -> Void,
        onToggleChecklistLine: @escaping (Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.draft = draft
        self.onEdit = onEdit
        self.onPrioritySet = onPrioritySet
        self.onToggleCompletion = onToggleCompletion
        self.onToggleChecklistLine = onToggleChecklistLine
        self.onDelete = onDelete
    }

    private var isCompleted: Bool {
        draft.completedAt != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            completionToggle

            VStack(alignment: .leading, spacing: 12) {
                MarkdownRenderedTaskView(
                    markdown: draft.markdown,
                    onTaskLineToggle: onToggleChecklistLine
                )
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .strikethrough(isCompleted, color: .secondary)
                    .opacity(isCompleted ? 0.65 : 1)

                taskMetadataSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            taskTools
        }
        .padding(12)
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
        .onChange(of: isCompleted) { oldValue, newValue in
            handleCompletionStateChange(from: oldValue, to: newValue)
        }
        .task(id: draft.id) {
            resetTransientUIState()
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
                        .font(.system(size: 14, weight: .black, design: .rounded))
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
        HStack(alignment: .center, spacing: 8) {
            priorityBadge

            if !draft.categories.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(draft.categories) { category in
                            OrbitCategoryChip(
                                title: category.name,
                                tint: Color(categoryHex: category.colorHex),
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

    private var priorityBadge: some View {
        Button {
            isPriorityPopoverPresented = true
        } label: {
            priorityBadgeLabel
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isPriorityPopoverPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            priorityPickerPopover
        }
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
    }

    private var priorityBadgeLabel: some View {
        let fillColor = priorityBadgeFillColor(for: draft.priority, isCompleted: isCompleted)
        let strokeColor = priorityBadgeStrokeColor(for: draft.priority, isCompleted: isCompleted)
        let textColor = priorityBadgeTextColor(for: draft.priority, isCompleted: isCompleted)

        return HStack(spacing: 6) {
            Image(systemName: priorityIcon(for: draft.priority))
                .font(.caption2.weight(.bold))

            Text(draft.priority.title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(NotePriority.allCases, id: \.self) { priority in
                Button {
                    onPrioritySet(priority)
                    isPriorityPopoverPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: priorityIcon(for: priority))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(priorityAccentColor(for: priority))

                        Text(priority.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 10)

                        if draft.priority == priority {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(priorityAccentColor(for: priority))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
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
        .onExitCommand {
            isPriorityPopoverPresented = false
        }
    }

    private var taskTools: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 10) {
                infoAction
                editAction
                deleteAction
            }

            if isCompleted {
                Text("Done")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TaskRowPalette.completionGreen)
            }
        }
        .padding(.leading, 10)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var infoAction: some View {
        Button {
            isTaskInfoPopoverPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
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

    private var editAction: some View {
        Button {
            onEdit()
        } label: {
            Image(systemName: "pencil")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.plain)
        .orbitInteractiveControl(
            scale: 1.06,
            lift: -1.0,
            shadowColor: TaskRowPalette.heroCyan.opacity(0.18),
            shadowRadius: 6
        )
        .foregroundStyle(.secondary)
        .accessibilityLabel("Edit task")
        .help("Edit task")
    }

    @ViewBuilder
    private var deleteAction: some View {
        if isDeleteConfirmationPending {
            Button("Confirm Deletion", role: .destructive) {
                onDelete()
            }
            .buttonStyle(.orbitDestructive)
        } else {
            Button {
                isDeleteConfirmationPending = true
                scheduleDeleteConfirmationReset()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .orbitInteractiveControl(
                scale: 1.06,
                lift: -1.0,
                shadowColor: Color.red.opacity(0.20),
                shadowRadius: 6
            )
            .foregroundStyle(.secondary)
            .accessibilityLabel("Delete task")
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

    private var taskInfoPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Information")
                .font(.subheadline.weight(.semibold))

            Text("Created: \(draft.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)

            if draft.carriedFromTaskID != nil {
                Text("Carried from: \(draft.carriedFromSessionName ?? "Previous session")")
                    .font(.caption)
            }
        }
        .foregroundStyle(.white.opacity(0.92))
        .frame(minWidth: 220, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            TaskRowPalette.heroNavy.opacity(0.95),
                            TaskRowPalette.heroCyan.opacity(0.95),
                            TaskRowPalette.heroAmber.opacity(0.82),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskRowPalette.heroCyan.opacity(0.48), lineWidth: 1)
        )
    }

    private func resetTransientUIState() {
        isDeleteConfirmationPending = false
        isTaskInfoPopoverPresented = false
        isPriorityPopoverPresented = false
        isCompletionBurstVisible = false
        completionBurstProgress = 0
        deleteConfirmationToken += 1
    }

    private func scheduleDeleteConfirmationReset() {
        deleteConfirmationToken += 1
        let token = deleteConfirmationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard token == deleteConfirmationToken, isDeleteConfirmationPending else { return }
            isDeleteConfirmationPending = false
        }
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

        withAnimation(.easeOut(duration: 0.54)) {
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

private enum TaskRowPalette {
    static let heroNavy = Color(red: 0.02, green: 0.14, blue: 0.24)
    static let heroCyan = Color(red: 0.02, green: 0.29, blue: 0.40)
    static let heroAmber = Color(red: 0.24, green: 0.19, blue: 0.04)
    static let completionGreen = Color(red: 0.36, green: 0.86, blue: 0.46)
    static let starlight = Color(red: 0.72, green: 0.93, blue: 1.00)
    static let supernovaRed = Color(red: 0.93, green: 0.38, blue: 0.48)
    static let priorityNone = Color(red: 0.62, green: 0.70, blue: 0.84)
    static let priorityLow = Color(red: 0.08, green: 0.86, blue: 0.78)
    static let priorityMedium = Color(red: 1.00, green: 0.74, blue: 0.18)
    static let priorityHigh = Color(red: 1.00, green: 0.27, blue: 0.54)

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

struct MarkdownRenderedTaskView: View {
    let markdown: String
    var onTaskLineToggle: ((Int) -> Void)? = nil

    var body: some View {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, line in
                lineView(line: line, lineIndex: lineIndex)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lineView(line: String, lineIndex: Int) -> some View {
        if let checklist = parseChecklistLine(line) {
            checklistLineRow(checklist, lineIndex: lineIndex)
        } else if let heading = parseHeadingLine(line) {
            headingLineRow(heading)
        } else if let unordered = parseUnorderedListLine(line) {
            listLineRow(
                marker: "•",
                text: unordered.text,
                indentation: unordered.indentation
            )
        } else if let ordered = parseOrderedListLine(line) {
            listLineRow(
                marker: "\(ordered.number).",
                text: ordered.text,
                indentation: ordered.indentation
            )
        } else if line.isEmpty {
            Text(" ")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(MarkdownAttributedRenderer.renderAttributed(markdown: line))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func headingLineRow(_ heading: HeadingLine) -> some View {
        Text(MarkdownAttributedRenderer.renderAttributed(markdown: heading.text.isEmpty ? " " : heading.text))
            .font(font(for: heading.level))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, indentationWidth(for: heading.indentation))
    }

    @ViewBuilder
    private func listLineRow(marker: String, text: String, indentation: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(MarkdownAttributedRenderer.renderAttributed(markdown: text.isEmpty ? " " : text))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, indentationWidth(for: indentation))
    }

    @ViewBuilder
    private func checklistLineRow(_ checklist: ChecklistLine, lineIndex: Int) -> some View {
        if let onTaskLineToggle {
            Button {
                onTaskLineToggle(lineIndex)
            } label: {
                checklistLineContent(checklist)
            }
            .buttonStyle(.plain)
            .help(checklist.isChecked ? "Uncheck checklist item" : "Check checklist item")
        } else {
            checklistLineContent(checklist)
        }
    }

    private func checklistLineContent(_ checklist: ChecklistLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: checklist.isChecked ? "checkmark.square.fill" : "square")
                .font(.body.weight(.semibold))
                .foregroundStyle(checklist.isChecked ? TaskRowPalette.completionGreen : .secondary)

            Text(MarkdownAttributedRenderer.renderAttributed(markdown: checklist.text.isEmpty ? " " : checklist.text))
                .frame(maxWidth: .infinity, alignment: .leading)
                .strikethrough(checklist.isChecked, color: .secondary)
                .opacity(checklist.isChecked ? 0.72 : 1)
        }
        .padding(.leading, indentationWidth(for: checklist.indentation))
    }

    private func indentationWidth(for indentation: String) -> CGFloat {
        let columns = indentation.reduce(0) { partialResult, character in
            partialResult + (character == "\t" ? 4 : 1)
        }
        return CGFloat(columns) * 6
    }

    private func font(for headingLevel: Int) -> Font {
        switch headingLevel {
        case 1:
            return .title3.weight(.bold)
        case 2:
            return .headline.weight(.semibold)
        default:
            return .subheadline.weight(.semibold)
        }
    }

    private func parseHeadingLine(_ line: String) -> HeadingLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.headingRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let marker = substring(line, match.range(at: 2)),
              let text = substring(line, match.range(at: 3))
        else {
            return nil
        }

        return HeadingLine(
            level: min(max(marker.count, 1), 6),
            indentation: indentation,
            text: text
        )
    }

    private func parseChecklistLine(_ line: String) -> ChecklistLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.checklistRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let marker = substring(line, match.range(at: 3)),
              let text = substring(line, match.range(at: 4))
        else {
            return nil
        }

        return ChecklistLine(
            indentation: indentation,
            isChecked: marker.lowercased() == "x",
            text: text
        )
    }

    private func parseUnorderedListLine(_ line: String) -> ListLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.unorderedListRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let text = substring(line, match.range(at: 3))
        else {
            return nil
        }

        return ListLine(indentation: indentation, text: text)
    }

    private func parseOrderedListLine(_ line: String) -> OrderedListLine? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = Self.orderedListRegex.firstMatch(in: line, options: [], range: range),
              let indentation = substring(line, match.range(at: 1)),
              let number = substring(line, match.range(at: 2)),
              let text = substring(line, match.range(at: 4))
        else {
            return nil
        }

        return OrderedListLine(indentation: indentation, number: number, text: text)
    }

    private func substring(_ line: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound else { return nil }
        guard let swiftRange = Range(range, in: line) else { return nil }
        return String(line[swiftRange])
    }

    private struct HeadingLine {
        let level: Int
        let indentation: String
        let text: String
    }

    private struct ListLine {
        let indentation: String
        let text: String
    }

    private struct ChecklistLine {
        let indentation: String
        let isChecked: Bool
        let text: String
    }

    private struct OrderedListLine {
        let indentation: String
        let number: String
        let text: String
    }

    private static let headingRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)(#{1,6})\s+(.*)$"#
    )

    private static let unorderedListRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+])\s+(.*)$"#
    )

    private static let checklistRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+])\s+\[( |x|X)\]\s+(.*)$"#
    )

    private static let orderedListRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)(\d+)([.)])\s+(.*)$"#
    )
}

private extension Color {
    init(categoryHex: String) {
        let normalized = FocusDefaults.normalizedCategoryColorHex(categoryHex)
        let hex = String(normalized.dropFirst())
        let value = UInt64(hex, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
