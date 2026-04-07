import SwiftUI

struct SessionTaskInteractiveRow: View {
    let draft: AppFeature.State.TaskDraft
    let isKeyboardHighlighted: Bool
    let onKeyboardPopoverDismissed: (() -> Void)?
    let onEditRequested: () -> Void
    let onPrioritySet: (NotePriority) -> Void
    let onToggleCompletion: () -> Void
    let onToggleChecklistLine: (Int) -> Void

    init(
        draft: AppFeature.State.TaskDraft,
        isKeyboardHighlighted: Bool = false,
        onKeyboardPopoverDismissed: (() -> Void)? = nil,
        onEditRequested: @escaping () -> Void,
        onPrioritySet: @escaping (NotePriority) -> Void,
        onToggleCompletion: @escaping () -> Void,
        onToggleChecklistLine: @escaping (Int) -> Void
    ) {
        self.draft = draft
        self.isKeyboardHighlighted = isKeyboardHighlighted
        self.onKeyboardPopoverDismissed = onKeyboardPopoverDismissed
        self.onEditRequested = onEditRequested
        self.onPrioritySet = onPrioritySet
        self.onToggleCompletion = onToggleCompletion
        self.onToggleChecklistLine = onToggleChecklistLine
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
            .accessibilityHint("Tap or click to edit. Press Tab or Shift-Tab to move between tasks. Up and Down Arrow also move between tasks. Press Return to edit. Press Space to toggle completion. Press Escape to clear task focus.")

            TaskRowFloatingTools(
                draft: draft
            )
            .padding(.top, 10)
            .padding(.trailing, 8)
        }
    }
}
