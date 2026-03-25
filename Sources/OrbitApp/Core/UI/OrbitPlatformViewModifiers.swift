import SwiftUI

extension View {
    @ViewBuilder
    func orbitOnExitCommand(perform action: @escaping () -> Void) -> some View {
#if os(macOS)
        self.onExitCommand(perform: action)
#else
        self
#endif
    }

    @ViewBuilder
    func orbitInteractiveKeyboardDismiss() -> some View {
#if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
#else
        self
#endif
    }

    @ViewBuilder
    func orbitInlineNavigationTitleDisplayMode() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}
