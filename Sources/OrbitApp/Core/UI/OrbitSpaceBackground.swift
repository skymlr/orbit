import AppKit
import SwiftUI

struct OrbitSpaceBackground: View {
    @Environment(\.orbitAppearance) private var appearance
    var style: OrbitBackgroundOption?
    var showsOrbitalLayer: Bool?

    private var resolvedStyle: OrbitBackgroundOption {
        style ?? appearance.background
    }

    private var resolvedShowsOrbitalLayer: Bool {
        showsOrbitalLayer ?? appearance.showsOrbitalLayer
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                baseBackground(size: proxy.size)

                if resolvedShowsOrbitalLayer {
                    OrbitOrbitalLayer()
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func baseBackground(size: CGSize) -> some View {
        switch resolvedStyle {
        case .spaceBlue:
            OrbitSpaceBlueBackground()
        case .skyBlue:
            OrbitTintBackground(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.28, blue: 0.56),
                        Color(red: 0.30, green: 0.61, blue: 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                glow: Color(red: 0.80, green: 0.92, blue: 1.00)
            )
        case .purple:
            OrbitTintBackground(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.10, blue: 0.26),
                        Color(red: 0.19, green: 0.13, blue: 0.41)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                glow: Color(red: 0.63, green: 0.48, blue: 0.92)
            )
        case .glass:
            OrbitGlassBackground(size: size)
        }
    }
}

private struct OrbitSpaceBlueBackground: View {
    var body: some View {
        ZStack {
            OrbitTheme.Gradients.spaceCanvas

            RadialGradient(
                colors: [
                    OrbitTheme.Palette.nebula.opacity(0.28),
                    .clear
                ],
                center: .init(x: 1, y: 1),
                startRadius: 10,
                endRadius: 2_000
            )
        }
    }
}

private struct OrbitTintBackground: View {
    let gradient: LinearGradient
    let glow: Color

    var body: some View {
        ZStack {
            gradient

            RadialGradient(
                colors: [
                    glow.opacity(0.36),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 720
            )

            RadialGradient(
                colors: [
                    glow.opacity(0.18),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 560
            )
        }
    }
}

private struct OrbitOrbitalLayer: View {
    var body: some View {
        ZStack {
            OrbitStarField()
            OrbitMotif()
        }
    }
}

private struct OrbitGlassBackground: View {
    let size: CGSize

    var body: some View {
        ZStack {
            OrbitWindowMaterialView(
                material: .hudWindow,
                blendingMode: .behindWindow
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color(red: 0.07, green: 0.12, blue: 0.20).opacity(0.14),
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct OrbitWindowMaterialView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.isEmphasized = true
    }
}

private struct OrbitStarField: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                ForEach(0..<160, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(starAlpha(for: index)))
                        .frame(width: starSize(for: index), height: starSize(for: index))
                        .position(
                            x: 18 + (width - 36) * starSeed(index: index, multiplier: 67, modulus: 997),
                            y: 18 + (height - 36) * starSeed(index: index, multiplier: 139, modulus: 941)
                        )
                }
            }
        }
    }

    private func starSeed(index: Int, multiplier: Int, modulus: Int) -> CGFloat {
        CGFloat((index * multiplier) % modulus) / CGFloat(modulus)
    }

    private func starSize(for index: Int) -> CGFloat {
        0.9 + CGFloat((index * 17) % 5) * 0.45
    }

    private func starAlpha(for index: Int) -> Double {
        0.14 + Double((index * 29) % 58) / 160
    }
}

private struct OrbitMotif: View {
    private struct PlanetSpec {
        var orbitIndex: Int
        var angle: CGFloat
        var size: CGFloat
        var color: Color
    }

    private let orbitFractions: [CGFloat] = [0.40, 0.55, 0.70, 0.85, 1.00]
    private let planets: [PlanetSpec] = [
        PlanetSpec(orbitIndex: 0, angle: 238, size: 0.011, color: OrbitTheme.Palette.planetIce),
        PlanetSpec(orbitIndex: 1, angle: 212, size: 0.013, color: OrbitTheme.Palette.planetGold),
        PlanetSpec(orbitIndex: 2, angle: 252, size: 0.015, color: OrbitTheme.Palette.planetCoral),
        PlanetSpec(orbitIndex: 3, angle: 226, size: 0.017, color: OrbitTheme.Palette.planetIce.opacity(0.95)),
        PlanetSpec(orbitIndex: 4, angle: 244, size: 0.018, color: OrbitTheme.Palette.planetGold.opacity(0.98)),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width, y: proxy.size.height)

            ZStack {
                sun(center: center, size: size)

                ForEach(Array(orbitFractions.enumerated()), id: \.offset) { index, fraction in
                    Circle()
                        .stroke(
                            OrbitTheme.Palette.orbitLine.opacity(0.05 + Double(index) * 0.03),
                            lineWidth: 0.8
                        )
                        .frame(width: size * fraction * 2, height: size * fraction * 2)
                        .position(center)
                }

                ForEach(Array(planets.enumerated()), id: \.offset) { _, planet in
                    let orbitIndex = min(max(planet.orbitIndex, 0), orbitFractions.count - 1)
                    let radius = size * orbitFractions[orbitIndex]
                    Circle()
                        .fill(planet.color.opacity(0.92))
                        .frame(width: size * planet.size, height: size * planet.size)
                        .position(pointOnOrbit(center: center, radius: radius, angleDegrees: planet.angle))
                }
            }
        }
    }

    @ViewBuilder
    private func sun(center: CGPoint, size: CGFloat) -> some View {
        let haloEndRadius = size * 0.40
        let coreEndRadius = size * 0.086

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OrbitTheme.Palette.sunHalo.opacity(0.55),
                            OrbitTheme.Palette.sunFlare.opacity(0.22),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: haloEndRadius
                    )
                )
                .frame(width: size * 0.88, height: size * 0.88)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OrbitTheme.Palette.sunCore,
                            OrbitTheme.Palette.sunCoreEdge
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: coreEndRadius
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                )
                .frame(width: size * 0.170, height: size * 0.170)
        }
        .position(center)
    }

    private func pointOnOrbit(center: CGPoint, radius: CGFloat, angleDegrees: CGFloat) -> CGPoint {
        let radians = angleDegrees * (.pi / 180)
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }
}
