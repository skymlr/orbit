import SwiftUI

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
                    .orbitFont(.caption2, weight: .bold)
            }

            Text(title)
                .lineLimit(1)

            if let count {
                Text("\(count)")
                    .orbitFont(.caption2, monospacedDigits: true)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.15))
                    )
            }
        }
        .orbitFont(.caption, weight: .semibold)
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
