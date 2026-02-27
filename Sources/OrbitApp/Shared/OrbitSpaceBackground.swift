import SwiftUI

struct OrbitSpaceBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.09, blue: 0.16),
                        Color(red: 0.06, green: 0.14, blue: 0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.20, green: 0.42, blue: 0.56).opacity(0.28),
                        .clear
                    ],
                    center: .init(x: 0.6, y: 0.32),
                    startRadius: 10,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.75
                )

                OrbitStarField()
                OrbitMotif()
            }
        }
        .ignoresSafeArea()
    }
}

private struct OrbitStarField: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                ForEach(0..<44, id: \.self) { index in
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
        1.2 + CGFloat((index * 17) % 3)
    }

    private func starAlpha(for index: Int) -> Double {
        0.16 + Double((index * 29) % 36) / 120
    }
}

private struct OrbitMotif: View {
    private struct PlanetSpec {
        var orbit: CGFloat
        var angle: CGFloat
        var size: CGFloat
        var color: Color
    }

    private let planets: [PlanetSpec] = [
        PlanetSpec(orbit: 0.18, angle: 24, size: 0.016, color: Color(red: 0.65, green: 0.86, blue: 0.96)),
        PlanetSpec(orbit: 0.29, angle: 205, size: 0.020, color: Color(red: 0.97, green: 0.71, blue: 0.44)),
        PlanetSpec(orbit: 0.40, angle: 302, size: 0.022, color: Color(red: 0.60, green: 0.74, blue: 0.92)),
        PlanetSpec(orbit: 0.52, angle: 132, size: 0.025, color: Color(red: 0.90, green: 0.54, blue: 0.34)),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.47)
            let orbitFractions: [CGFloat] = [0.18, 0.29, 0.40, 0.52]

            ZStack {
                ForEach(Array(orbitFractions.enumerated()), id: \.offset) { index, fraction in
                    Circle()
                        .stroke(
                            Color(red: 0.58, green: 0.84, blue: 0.95)
                                .opacity(0.12 + Double(index) * 0.08),
                            lineWidth: 1.35
                        )
                        .frame(width: size * fraction * 2, height: size * fraction * 2)
                        .position(center)
                }

                Circle()
                    .fill(Color(red: 0.98, green: 0.75, blue: 0.30).opacity(0.90))
                    .frame(width: size * 0.085, height: size * 0.085)
                    .position(center)

                Circle()
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    .frame(width: size * 0.10, height: size * 0.10)
                    .position(center)

                ForEach(Array(planets.enumerated()), id: \.offset) { _, planet in
                    Circle()
                        .fill(planet.color.opacity(0.92))
                        .frame(width: size * planet.size, height: size * planet.size)
                        .position(pointOnOrbit(center: center, radius: size * planet.orbit, angleDegrees: planet.angle))
                }
            }
        }
    }

    private func pointOnOrbit(center: CGPoint, radius: CGFloat, angleDegrees: CGFloat) -> CGPoint {
        let radians = angleDegrees * (.pi / 180)
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }
}
