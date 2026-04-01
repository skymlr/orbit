import SwiftUI

struct OrbitLaunchLoadingScreen: View {
    var message: String = "Loading your focus orbit..."
    var showsBackground = true

    var body: some View {
        ZStack {
            if showsBackground {
                OrbitSpaceBackground()
            }

            VStack(spacing: 18) {
                OrbitLaunchEmblem()
                    .frame(width: 124, height: 124)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Orbit")
                        .orbitFont(size: 34, weight: .bold)
                        .foregroundStyle(.white)

                    Text(message)
                        .orbitFont(.title3, weight: .semibold)
                        .foregroundStyle(OrbitTheme.Palette.starlight.opacity(0.96))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct OrbitLaunchEmblem: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let primaryRotation = reduceMotion ? 0 : time * 24
            let secondaryRotation = reduceMotion ? 0 : time * -14

            ZStack {
                Circle()
                    .fill(OrbitTheme.Gradients.sunHalo)
                    .frame(width: 118, height: 118)

                orbitRing(
                    diameter: 96,
                    planetSize: 10,
                    color: OrbitTheme.Palette.planetGold,
                    rotation: primaryRotation
                )

                orbitRing(
                    diameter: 68,
                    planetSize: 8,
                    color: OrbitTheme.Palette.planetIce,
                    rotation: secondaryRotation
                )

                Circle()
                    .fill(OrbitTheme.Gradients.sunCore)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Circle()
                            .stroke(OrbitTheme.Palette.sunCoreEdge.opacity(0.9), lineWidth: 1)
                    }
                    .shadow(color: OrbitTheme.Palette.sunHalo.opacity(0.45), radius: 12)
            }
        }
    }

    private func orbitRing(
        diameter: CGFloat,
        planetSize: CGFloat,
        color: Color,
        rotation: Double
    ) -> some View {
        ZStack {
            Circle()
                .stroke(OrbitTheme.Palette.orbitLine.opacity(0.28), lineWidth: 1)
                .frame(width: diameter, height: diameter)

            Circle()
                .fill(color)
                .frame(width: planetSize, height: planetSize)
                .offset(y: -(diameter / 2))
                .shadow(color: color.opacity(0.4), radius: 6)
        }
        .rotationEffect(.degrees(rotation))
    }
}

#if DEBUG
struct OrbitLaunchLoadingScreen_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OrbitLaunchLoadingScreen()
                .orbitAppearance(.default)
                .preferredColorScheme(.dark)
                .frame(width: 1_280, height: 900)
                .previewDisplayName("Desktop")

            OrbitLaunchLoadingScreen()
                .orbitAppearance(.default)
                .preferredColorScheme(.dark)
                .frame(width: 390, height: 844)
                .previewDisplayName("Phone")
        }
    }
}
#endif
