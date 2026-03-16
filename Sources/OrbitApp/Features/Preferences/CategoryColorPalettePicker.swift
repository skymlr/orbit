import SwiftUI

struct CategoryColorPalettePicker: View {
    @Binding var selectedHex: String

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 10),
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(FocusDefaults.categoryColorOptions, id: \.self) { colorHex in
                let isSelected = selectedHex == colorHex

                Button {
                    selectedHex = colorHex
                } label: {
                    Circle()
                        .fill(Color(orbitHex: colorHex))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isSelected ? 0.95 : 0.45), lineWidth: isSelected ? 2 : 1)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.22), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .orbitInteractiveControl(
                    scale: 1.12,
                    lift: -1.0,
                    shadowColor: Color.white.opacity(0.18),
                    shadowRadius: 4
                )
                .help(colorHex)
                .accessibilityLabel("Category color \(colorHex)")
            }
        }
    }
}
