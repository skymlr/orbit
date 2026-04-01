import SwiftUI

struct SessionTaskInteractiveRow: View {
    let draft: AppFeature.State.TaskDraft
    let isKeyboardHighlighted: Bool
    let onKeyboardPopoverDismissed: (() -> Void)?
    let onEditRequested: () -> Void
    let onPrioritySet: (NotePriority) -> Void
    let onToggleCompletion: () -> Void
    let onToggleChecklistLine: (Int) -> Void
    let onDeleteRequested: () -> Void

    init(
        draft: AppFeature.State.TaskDraft,
        isKeyboardHighlighted: Bool = false,
        onKeyboardPopoverDismissed: (() -> Void)? = nil,
        onEditRequested: @escaping () -> Void,
        onPrioritySet: @escaping (NotePriority) -> Void,
        onToggleCompletion: @escaping () -> Void,
        onToggleChecklistLine: @escaping (Int) -> Void,
        onDeleteRequested: @escaping () -> Void
    ) {
        self.draft = draft
        self.isKeyboardHighlighted = isKeyboardHighlighted
        self.onKeyboardPopoverDismissed = onKeyboardPopoverDismissed
        self.onEditRequested = onEditRequested
        self.onPrioritySet = onPrioritySet
        self.onToggleCompletion = onToggleCompletion
        self.onToggleChecklistLine = onToggleChecklistLine
        self.onDeleteRequested = onDeleteRequested
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TaskRow(
                draft: draft,
                isKeyboardHighlighted: isKeyboardHighlighted,
                onKeyboardPopoverDismissed: onKeyboardPopoverDismissed,
                onEditRequested: onEditRequested,
                onPrioritySet: onPrioritySet,
                onToggleCompletion: onToggleCompletion,
                onToggleChecklistLine: onToggleChecklistLine
            )
            .accessibilityAddTraits(isKeyboardHighlighted ? .isSelected : [])
            .accessibilityHint("Tap or click to edit. Press Up or Down Arrow to move between tasks. Press Return to edit. Press Space to toggle completion. Press Escape to clear task focus.")

            TaskRowFloatingTools(
                draft: draft,
                onEdit: onEditRequested,
                onDelete: onDeleteRequested
            )
            .padding(.top, 10)
            .padding(.trailing, 8)
        }
    }
}
