import SwiftUI

enum OrbitTheme {
    enum Palette {
        static let spaceTop = Color(red: 0.04, green: 0.09, blue: 0.16)
        static let spaceBottom = Color(red: 0.06, green: 0.14, blue: 0.24)
        static let nebula = Color(red: 0.20, green: 0.42, blue: 0.56)
        static let orbitLine = Color(red: 0.58, green: 0.84, blue: 0.95)
        static let starlight = Color(red: 0.72, green: 0.93, blue: 1.00)

        static let heroNavy = Color(red: 0.02, green: 0.14, blue: 0.24)
        static let heroCyan = Color(red: 0.02, green: 0.29, blue: 0.40)
        static let heroAmber = Color(red: 0.24, green: 0.19, blue: 0.04)

        static let sunHalo = Color(red: 1.00, green: 0.83, blue: 0.46)
        static let sunFlare = Color(red: 0.96, green: 0.63, blue: 0.26)
        static let sunCore = Color(red: 1.00, green: 0.93, blue: 0.70)
        static let sunCoreEdge = Color(red: 1.00, green: 0.74, blue: 0.39)

        static let planetIce = Color(red: 0.67, green: 0.88, blue: 0.97)
        static let planetGold = Color(red: 0.97, green: 0.74, blue: 0.44)
        static let planetCoral = Color(red: 0.94, green: 0.66, blue: 0.49)

        static let completionGreen = Color(red: 0.36, green: 0.86, blue: 0.46)
        static let toastSuccess = Color(red: 0.38, green: 0.85, blue: 0.60)
        static let toastFailure = Color(red: 0.98, green: 0.45, blue: 0.42)

        static let priorityNone = Color(red: 0.62, green: 0.70, blue: 0.84)
        static let priorityLow = Color(red: 0.08, green: 0.86, blue: 0.78)
        static let priorityMedium = Color(red: 1.00, green: 0.74, blue: 0.18)
        static let priorityHigh = Color(red: 1.00, green: 0.27, blue: 0.54)

        static let lightPanel = Color(red: 0.90, green: 0.95, blue: 0.99)
        static let lightPanelSoft = Color(red: 0.92, green: 0.96, blue: 1.00)
        static let lightText = Color(red: 0.05, green: 0.20, blue: 0.32)
        static let lightTextSecondary = Color(red: 0.10, green: 0.30, blue: 0.43)
        static let lightStroke = Color(red: 0.08, green: 0.43, blue: 0.62)
        static let lightStrokeSoft = Color(red: 0.11, green: 0.46, blue: 0.65)

        static let glassFill = Color.white.opacity(0.08)
        static let glassFillSubtle = Color.white.opacity(0.05)
        static let glassBorder = Color.white.opacity(0.14)
        static let glassBorderStrong = Color.white.opacity(0.20)
    }

    enum Gradients {
        static let spaceCanvas = LinearGradient(
            colors: [
                Palette.spaceTop,
                Palette.spaceBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        static let heroButtonBackground = LinearGradient(
            colors: [
                Palette.heroNavy,
                Palette.heroCyan,
                Palette.heroAmber
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let heroButtonStroke = LinearGradient(
            colors: [
                Palette.orbitLine.opacity(0.95),
                Palette.sunFlare.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let primaryButtonBackground = LinearGradient(
            colors: [
                Palette.heroNavy.opacity(1.0),
                Palette.heroCyan.opacity(1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let taskInfoPanel = LinearGradient(
            colors: [
                Palette.heroNavy.opacity(0.95),
                Palette.heroCyan.opacity(0.95),
                Palette.heroAmber.opacity(0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let sunHalo = RadialGradient(
            colors: [
                Palette.sunHalo.opacity(0.55),
                Palette.sunFlare.opacity(0.22),
                .clear
            ],
            center: .center,
            startRadius: 2,
            endRadius: 120
        )

        static let sunCore = RadialGradient(
            colors: [
                Palette.sunCore,
                Palette.sunCoreEdge
            ],
            center: .center,
            startRadius: 1,
            endRadius: 28
        )
    }

    enum Radius {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 10
        static let card: CGFloat = 12
        static let panel: CGFloat = 14
        static let button: CGFloat = 16
        static let hero: CGFloat = 22
    }

    enum Motion {
        static let press = 0.12
        static let hover = 0.14
        static let micro = 0.16
        static let standard = 0.18
        static let relaxed = 0.24
        static let celebration = 0.54
    }
}

extension Color {
    init(orbitHex hex: String) {
        let normalized = FocusDefaults.normalizedCategoryColorHex(hex)
        let value = UInt64(normalized.dropFirst(), radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
