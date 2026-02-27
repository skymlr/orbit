import SwiftUI

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
    }
}

struct OrbitDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.95), Color(red: 0.70, green: 0.08, blue: 0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
