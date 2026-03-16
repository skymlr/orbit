import SwiftUI

extension AnyTransition {
    static var orbitMicro: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)),
            removal: .opacity.combined(with: .scale(scale: 1.01))
        )
    }
}
