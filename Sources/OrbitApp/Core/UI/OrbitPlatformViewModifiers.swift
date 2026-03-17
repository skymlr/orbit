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
    func orbitHideSidebarToggle() -> some View {
#if os(macOS)
        self.toolbar(removing: .sidebarToggle)
#else
        self
#endif
    }
}
