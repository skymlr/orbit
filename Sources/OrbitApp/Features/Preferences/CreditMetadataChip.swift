import SwiftUI

struct CreditMetadataChip: View {
    let title: String
    var usesMonospacedDigits = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .orbitFont(.caption, weight: .semibold, monospacedDigits: usesMonospacedDigits)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var textColor: Color {
        colorScheme == .dark
            ? .primary
            : OrbitTheme.Palette.lightTextSecondary
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.glassFillSubtle
            : OrbitTheme.Palette.lightPanelSoft
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.glassBorderStrong.opacity(0.88)
            : OrbitTheme.Palette.lightStrokeSoft.opacity(0.42)
    }
}
