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
}
