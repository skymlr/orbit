#if os(macOS)
import AppKit
import SwiftUI

struct MarkdownSourceTextView: NSViewRepresentable {
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

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = CommandTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 80)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .clear
        textView.font = OrbitTypography.appKitFont(.body, appearance: appearance)
        textView.delegate = context.coordinator
        textView.string = text
        textView.setSelectedRange(selectionRange)
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onMoveToNextField = onMoveToNextField
        textView.onMoveToPreviousField = onMoveToPreviousField

        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        guard let textView = nsView.documentView as? CommandTextView else { return }
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onMoveToNextField = onMoveToNextField
        textView.onMoveToPreviousField = onMoveToPreviousField

        context.coordinator.isSynchronizingFromSwiftUI = true
        defer { context.coordinator.isSynchronizingFromSwiftUI = false }

        if textView.string != text {
            textView.string = text
        }

        let expectedFont = OrbitTypography.appKitFont(.body, appearance: appearance)
        if textView.font?.fontName != expectedFont.fontName || textView.font?.pointSize != expectedFont.pointSize {
            textView.font = expectedFont
        }

        let currentSelection = textView.selectedRange()
        if currentSelection != selectionRange {
            textView.setSelectedRange(selectionRange)
        }

        context.coordinator.scheduleFocusUpdate(for: textView, isFocused: isFocused)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownSourceTextView
        var isSynchronizingFromSwiftUI = false

        init(parent: MarkdownSourceTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isSynchronizingFromSwiftUI else { return }
            let updatedText = textView.string
            guard parent.text != updatedText else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isSynchronizingFromSwiftUI else { return }
                guard self.parent.text != updatedText else { return }
                self.parent.text = updatedText
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            updateFocusState(isFocused: true)
        }

        func textDidEndEditing(_ notification: Notification) {
            updateFocusState(isFocused: false)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isSynchronizingFromSwiftUI else { return }
            if textView.window?.firstResponder === textView {
                updateFocusState(isFocused: true)
            }
            let newSelection = textView.selectedRange()
            guard parent.selectionRange != newSelection else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isSynchronizingFromSwiftUI else { return }
                guard self.parent.selectionRange != newSelection else { return }
                self.parent.selectionRange = newSelection
            }
        }

        func scheduleFocusUpdate(for textView: NSTextView, isFocused: Bool) {
            scheduleFocusUpdate(for: textView, isFocused: isFocused, remainingRetries: 6)
        }

        private func scheduleFocusUpdate(
            for textView: NSTextView,
            isFocused: Bool,
            remainingRetries: Int
        ) {
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                guard let window = textView.window else {
                    guard remainingRetries > 0 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self, weak textView] in
                        guard let self, let textView else { return }
                        self.scheduleFocusUpdate(
                            for: textView,
                            isFocused: isFocused,
                            remainingRetries: remainingRetries - 1
                        )
                    }
                    return
                }

                if isFocused, window.firstResponder !== textView {
                    window.makeFirstResponder(textView)
                } else if !isFocused, window.firstResponder === textView {
                    window.makeFirstResponder(nil)
                }
            }
        }

        private func updateFocusState(isFocused: Bool) {
            guard !isSynchronizingFromSwiftUI else { return }
            guard parent.isFocused != isFocused else { return }
            parent.isFocused = isFocused
        }
    }
}
#endif
