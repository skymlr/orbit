import SwiftUI

enum OrbitSurfaceFillStyle {
    case settingsCard
    case thinMaterial
    case ultraThinMaterial
}

extension View {
    func orbitSurfaceCard(
        fillStyle: OrbitSurfaceFillStyle = .settingsCard,
        cornerRadius: CGFloat = OrbitTheme.Radius.panel,
        borderColor: Color = OrbitTheme.Palette.glassBorderStrong,
        lineWidth: CGFloat = 1,
        overlayColor: Color? = nil,
        shadowColor: Color = .clear,
        shadowRadius: CGFloat = 0,
        shadowY: CGFloat = 0
    ) -> some View {
        modifier(
            OrbitSurfaceCardModifier(
                fillStyle: fillStyle,
                cornerRadius: cornerRadius,
                borderColor: borderColor,
                lineWidth: lineWidth,
                overlayColor: overlayColor,
                shadowColor: shadowColor,
                shadowRadius: shadowRadius,
                shadowY: shadowY
            )
        )
    }
}

struct OrbitIndexCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var tint: Color = OrbitTheme.Palette.orbitLine
    var showsChevron = true

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .orbitFont(.headline, weight: .semibold)

                Text(subtitle)
                    .orbitFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OrbitTheme.Palette.priorityNone.opacity(0.82))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .orbitSurfaceCard()
    }
}

private struct OrbitSurfaceCardModifier: ViewModifier {
    let fillStyle: OrbitSurfaceFillStyle
    let cornerRadius: CGFloat
    let borderColor: Color
    let lineWidth: CGFloat
    let overlayColor: Color?
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(fillStyle.backgroundStyle)
                    .overlay {
                        if let overlayColor {
                            shape.fill(overlayColor)
                        }
                    }
            }
            .overlay {
                shape.stroke(borderColor, lineWidth: lineWidth)
            }
            .clipShape(shape)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }
}

private extension OrbitSurfaceFillStyle {
    var backgroundStyle: AnyShapeStyle {
        switch self {
        case .settingsCard:
            return AnyShapeStyle(Color.white.opacity(0.10))
        case .thinMaterial:
            return AnyShapeStyle(.thinMaterial)
        case .ultraThinMaterial:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}
