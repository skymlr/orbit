import SwiftUI

struct TaskRowKeyboardShortcutMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keyboard")
                .orbitFont(.caption2, weight: .bold)
                .foregroundStyle(.secondary)

            keyboardShortcutRow(key: "Return", action: "Edit task")
            keyboardShortcutRow(key: "Space", action: "Mark complete")
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func keyboardShortcutRow(key: String, action: String) -> some View {
        HStack(spacing: 8) {
            Text(key)
                .orbitFont(.caption2, weight: .semibold, monospaced: true)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .foregroundStyle(.secondary)

            Text(action)
                .orbitFont(.caption2, weight: .semibold)
        }
    }
}
