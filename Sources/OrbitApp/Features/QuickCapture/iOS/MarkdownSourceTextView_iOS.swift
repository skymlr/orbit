import SwiftUI

#if os(iOS)
import UIKit

struct MarkdownSourceTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange
    @Binding var isFocused: Bool
    let appearance: AppearanceSettings

    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onMoveToNextField: (() -> Void)?
    var onMoveToPreviousField: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = OrbitCommandTextView()
        textView.backgroundColor = .clear
        textView.font = OrbitTypography.appKitFont(.body, appearance: appearance)
        textView.delegate = context.coordinator
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .sentences
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardDismissMode = .interactive
        textView.onCancel = onCancel
        textView.onMoveToNextField = onMoveToNextField
        textView.onMoveToPreviousField = onMoveToPreviousField
        textView.selectedRange = selectionRange
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        guard let textView = uiView as? OrbitCommandTextView else { return }
        textView.onCancel = onCancel
        textView.onMoveToNextField = onMoveToNextField
        textView.onMoveToPreviousField = onMoveToPreviousField

        context.coordinator.isSynchronizingFromSwiftUI = true
        defer { context.coordinator.isSynchronizingFromSwiftUI = false }

        if textView.text != text {
            textView.text = text
        }

        let expectedFont = OrbitTypography.appKitFont(.body, appearance: appearance)
        if textView.font?.fontName != expectedFont.fontName || textView.font?.pointSize != expectedFont.pointSize {
            textView.font = expectedFont
        }

        if textView.selectedRange != selectionRange {
            textView.selectedRange = selectionRange
        }

        if isFocused, !textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        } else if !isFocused, textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.resignFirstResponder()
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownSourceTextView
        var isSynchronizingFromSwiftUI = false

        init(parent: MarkdownSourceTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            updateFocusState(isFocused: true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            updateFocusState(isFocused: false)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSynchronizingFromSwiftUI else { return }
            let updatedText = textView.text ?? ""
            guard parent.text != updatedText else { return }
            parent.text = updatedText
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isSynchronizingFromSwiftUI else { return }
            let newSelection = textView.selectedRange
            guard parent.selectionRange != newSelection else { return }
            parent.selectionRange = newSelection
            updateFocusState(isFocused: textView.isFirstResponder)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText: String
        ) -> Bool {
            guard replacementText == "\n" else { return true }
            guard let command = MarkdownTextCommandHandler.handleReturn(
                in: textView.text ?? "",
                selection: range
            ) else {
                return true
            }

            isSynchronizingFromSwiftUI = true
            textView.text = command.text
            textView.selectedRange = command.selection
            isSynchronizingFromSwiftUI = false
            parent.text = command.text
            parent.selectionRange = command.selection
            return false
        }

        private func updateFocusState(isFocused: Bool) {
            guard !isSynchronizingFromSwiftUI else { return }
            guard parent.isFocused != isFocused else { return }
            parent.isFocused = isFocused
        }
    }
}

private final class OrbitCommandTextView: UITextView {
    var onCancel: (() -> Void)?
    var onMoveToNextField: (() -> Void)?
    var onMoveToPreviousField: (() -> Void)?

    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = [
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(cancelPressed)),
            UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(tabPressed)),
            UIKeyCommand(input: "\t", modifierFlags: [.shift], action: #selector(backtabPressed)),
        ]
        if let existing = super.keyCommands {
            commands.append(contentsOf: existing)
        }
        return commands
    }

    @objc
    private func cancelPressed() {
        onCancel?()
    }

    @objc
    private func tabPressed() {
        onMoveToNextField?()
    }

    @objc
    private func backtabPressed() {
        onMoveToPreviousField?()
    }
}
#endif
