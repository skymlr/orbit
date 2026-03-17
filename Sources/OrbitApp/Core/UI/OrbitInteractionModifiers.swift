import SwiftUI

#if os(macOS)
import AppKit

private struct OrbitPointerCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var hasPushedCursor = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovered in
                if isHovered && isEnabled {
                    pushCursorIfNeeded()
                } else {
                    popCursorIfNeeded()
                }
            }
            .onChange(of: isEnabled) { _, enabled in
                guard !enabled else { return }
                popCursorIfNeeded()
            }
            .onDisappear {
                popCursorIfNeeded()
            }
    }

    private func pushCursorIfNeeded() {
        guard !hasPushedCursor else { return }
        NSCursor.pointingHand.push()
        hasPushedCursor = true
    }

    private func popCursorIfNeeded() {
        guard hasPushedCursor else { return }
        NSCursor.pop()
        hasPushedCursor = false
    }
}

private struct OrbitHoverEffectModifier: ViewModifier {
    let scale: CGFloat
    let lift: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let isActive = isHovered && isEnabled
        let effectiveScale = reduceMotion ? 1 : scale
        let effectiveLift = reduceMotion ? 0 : lift

        content
            .scaleEffect(isActive ? effectiveScale : 1)
            .offset(y: isActive ? effectiveLift : 0)
            .shadow(
                color: isActive ? shadowColor : .clear,
                radius: shadowRadius,
                x: 0,
                y: abs(effectiveLift) + 2
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: OrbitTheme.Motion.hover),
                value: isHovered
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func orbitPointerCursor() -> some View {
        modifier(OrbitPointerCursorModifier())
    }

    func orbitHoverEffect(
        scale: CGFloat = 1.02,
        lift: CGFloat = -1.5,
        shadowColor: Color = OrbitTheme.Palette.heroCyan.opacity(0.22),
        shadowRadius: CGFloat = 10
    ) -> some View {
        modifier(
            OrbitHoverEffectModifier(
                scale: scale,
                lift: lift,
                shadowColor: shadowColor,
                shadowRadius: shadowRadius
            )
        )
    }

    func orbitInteractiveControl(
        scale: CGFloat = 1.02,
        lift: CGFloat = -1.5,
        shadowColor: Color = OrbitTheme.Palette.heroCyan.opacity(0.22),
        shadowRadius: CGFloat = 10
    ) -> some View {
        orbitHoverEffect(
            scale: scale,
            lift: lift,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius
        )
        .orbitPointerCursor()
    }
}
#else
extension View {
    func orbitPointerCursor() -> some View {
        self
    }

    func orbitHoverEffect(
        scale: CGFloat = 1.02,
        lift: CGFloat = -1.5,
        shadowColor: Color = OrbitTheme.Palette.heroCyan.opacity(0.22),
        shadowRadius: CGFloat = 10
    ) -> some View {
        self
    }

    func orbitInteractiveControl(
        scale: CGFloat = 1.02,
        lift: CGFloat = -1.5,
        shadowColor: Color = OrbitTheme.Palette.heroCyan.opacity(0.22),
        shadowRadius: CGFloat = 10
    ) -> some View {
        self
    }
}
#endif
