import AppKit
import SwiftUI

extension AnyTransition {
    static var orbitMicro: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)),
            removal: .opacity.combined(with: .scale(scale: 1.01))
        )
    }
}

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

private enum OrbitButtonPalette {
    static let heroBackground = OrbitTheme.Gradients.heroButtonBackground
    static let heroStroke = OrbitTheme.Gradients.heroButtonStroke
    static let primaryBackground = OrbitTheme.Gradients.primaryButtonBackground
}

struct OrbitHeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.hero, style: .continuous)
                    .fill(OrbitButtonPalette.heroBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.hero, style: .continuous)
                    .stroke(OrbitButtonPalette.heroStroke, lineWidth: 1.3)
            )
            .shadow(color: OrbitTheme.Palette.heroCyan.opacity(0.25), radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: OrbitTheme.Motion.press), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.015,
                lift: -2.0,
                shadowColor: OrbitTheme.Palette.heroCyan.opacity(0.32),
                shadowRadius: 12
            )
    }
}

struct OrbitPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.button, style: .continuous)
                    .fill(OrbitButtonPalette.primaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.button, style: .continuous)
                    .stroke(OrbitTheme.Palette.heroCyan.opacity(0.55), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: OrbitTheme.Motion.press), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.014,
                lift: -1.4,
                shadowColor: OrbitTheme.Palette.heroCyan.opacity(0.24),
                shadowRadius: 10
            )
    }
}

struct OrbitSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(secondaryTextColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.button, style: .continuous)
                    .fill(secondaryBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.button, style: .continuous)
                    .stroke(secondaryStrokeColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: OrbitTheme.Motion.press), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.012,
                lift: -1.2,
                shadowColor: secondaryHoverShadowColor,
                shadowRadius: 8
            )
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .primary
            : OrbitTheme.Palette.lightText
    }

    private var secondaryBackgroundColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.glassFill
            : OrbitTheme.Palette.lightPanel
    }

    private var secondaryStrokeColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.heroCyan.opacity(0.38)
            : OrbitTheme.Palette.lightStroke.opacity(0.52)
    }

    private var secondaryHoverShadowColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.heroCyan.opacity(0.16)
            : OrbitTheme.Palette.heroCyan.opacity(0.22)
    }
}

struct OrbitQuietButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(quietTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(quietBackgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(quietStrokeColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.01,
                lift: -1.0,
                shadowColor: quietHoverShadowColor,
                shadowRadius: 6
            )
    }

    private var quietTextColor: Color {
        colorScheme == .dark
            ? .secondary
            : OrbitTheme.Palette.lightTextSecondary
    }

    private var quietBackgroundColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.glassFillSubtle
            : OrbitTheme.Palette.lightPanelSoft
    }

    private var quietStrokeColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.glassBorderStrong.opacity(0.9)
            : OrbitTheme.Palette.lightStrokeSoft.opacity(0.40)
    }

    private var quietHoverShadowColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : OrbitTheme.Palette.heroCyan.opacity(0.16)
    }
}

struct OrbitDestructiveButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(.systemRed))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(destructiveBackgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(destructiveStrokeColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: OrbitTheme.Motion.press), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.01,
                lift: -1.0,
                shadowColor: OrbitTheme.Palette.toastFailure.opacity(0.18),
                shadowRadius: 6
            )
    }

    private var destructiveBackgroundColor: Color {
        colorScheme == .dark
            ? Color.red.opacity(0.14)
            : Color.red.opacity(0.10)
    }

    private var destructiveStrokeColor: Color {
        colorScheme == .dark
            ? Color.red.opacity(0.44)
            : Color.red.opacity(0.56)
    }
}

struct OrbitCategoryChip: View {
    let title: String
    let tint: Color
    var isSelected = true
    var showsCheckmark = false
    var count: Int?

    var body: some View {
        HStack(spacing: 6) {
            if showsCheckmark && isSelected {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
            }

            Text(title)
                .lineLimit(1)

            if let count {
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.15))
                    )
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? tint.opacity(0.28) : Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? tint.opacity(0.95) : Color.white.opacity(0.22), lineWidth: 1)
        )
    }
}

extension ButtonStyle where Self == OrbitHeroButtonStyle {
    static var orbitHero: OrbitHeroButtonStyle { OrbitHeroButtonStyle() }
}

extension ButtonStyle where Self == OrbitPrimaryButtonStyle {
    static var orbitPrimary: OrbitPrimaryButtonStyle { OrbitPrimaryButtonStyle() }
}

extension ButtonStyle where Self == OrbitSecondaryButtonStyle {
    static var orbitSecondary: OrbitSecondaryButtonStyle { OrbitSecondaryButtonStyle() }
}

extension ButtonStyle where Self == OrbitQuietButtonStyle {
    static var orbitQuiet: OrbitQuietButtonStyle { OrbitQuietButtonStyle() }
}

extension ButtonStyle where Self == OrbitDestructiveButtonStyle {
    static var orbitDestructive: OrbitDestructiveButtonStyle { OrbitDestructiveButtonStyle() }
}

#if DEBUG
private struct OrbitButtonStylesPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Begin Focus Session")
                        .font(.headline.weight(.semibold))
                    Text("Track tasks, priorities, and progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.orbitHero)

            HStack(spacing: 10) {
                Button("Add Task") {
                }
                .buttonStyle(.orbitPrimary)

                Button("Rename Session") {
                }
                .buttonStyle(.orbitSecondary)
            }

            HStack(spacing: 12) {
                Button("Skip") {
                }
                .buttonStyle(.orbitQuiet)

                Button("Delete Session") {
                }
                .buttonStyle(.orbitDestructive)
            }
        }
        .padding(20)
        .frame(width: 430, alignment: .leading)
        .background {
            OrbitSpaceBackground()
        }
    }
}

struct OrbitButtonStyles_Previews: PreviewProvider {
    static var previews: some View {
        OrbitButtonStylesPreviewGallery()
            .preferredColorScheme(.dark)
    }
}
#endif
