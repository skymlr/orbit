import SwiftUI

struct OrbitToastView: View {
    let toast: AppFeature.State.Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accentColor)

            Text(toast.message)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .shadow(color: accentColor.opacity(0.24), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch toast.tone {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    private var accentColor: Color {
        switch toast.tone {
        case .success:
            return Color(red: 0.38, green: 0.85, blue: 0.60)
        case .failure:
            return Color(red: 0.98, green: 0.45, blue: 0.42)
        }
    }

    private var borderColor: Color {
        switch toast.tone {
        case .success:
            return Color(red: 0.38, green: 0.85, blue: 0.60).opacity(0.55)
        case .failure:
            return Color(red: 0.98, green: 0.45, blue: 0.42).opacity(0.55)
        }
    }
}

extension AnyTransition {
    static var orbitToastNotification: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .trailing)
        )
    }
}
