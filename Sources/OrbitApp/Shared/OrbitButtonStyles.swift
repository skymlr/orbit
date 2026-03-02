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
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered && isEnabled ? scale : 1)
            .offset(y: isHovered && isEnabled ? lift : 0)
            .shadow(
                color: isHovered && isEnabled ? shadowColor : .clear,
                radius: shadowRadius,
                x: 0,
                y: abs(lift) + 2
            )
            .animation(.easeOut(duration: 0.14), value: isHovered)
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
        shadowColor: Color = Color.cyan.opacity(0.22),
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
        shadowColor: Color = Color.cyan.opacity(0.22),
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
    static let heroBackground = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.14, blue: 0.24),
            Color(red: 0.02, green: 0.29, blue: 0.40),
            Color(red: 0.24, green: 0.19, blue: 0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroStroke = LinearGradient(
        colors: [
            Color.cyan.opacity(0.95),
            Color.orange.opacity(0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryBackground = LinearGradient(
        colors: [
            Color(red: 0.03, green: 0.20, blue: 0.32),
            Color(red: 0.03, green: 0.30, blue: 0.42)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct OrbitHeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(OrbitButtonPalette.heroBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(OrbitButtonPalette.heroStroke, lineWidth: 1.3)
            )
            .shadow(color: Color.cyan.opacity(0.25), radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.015,
                lift: -2.0,
                shadowColor: Color.cyan.opacity(0.32),
                shadowRadius: 12
            )
    }
}

struct OrbitPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OrbitButtonPalette.primaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cyan.opacity(0.55), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.014,
                lift: -1.4,
                shadowColor: Color.cyan.opacity(0.24),
                shadowRadius: 10
            )
    }
}

struct OrbitSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cyan.opacity(0.38), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.012,
                lift: -1.2,
                shadowColor: Color.cyan.opacity(0.16),
                shadowRadius: 8
            )
    }
}

struct OrbitQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.01,
                lift: -1.0,
                shadowColor: Color.white.opacity(0.14),
                shadowRadius: 6
            )
    }
}

struct OrbitDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .foregroundStyle(Color(.systemRed))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .orbitInteractiveControl(
                scale: 1.01,
                lift: -1.0,
                shadowColor: Color.red.opacity(0.18),
                shadowRadius: 6
            )
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
