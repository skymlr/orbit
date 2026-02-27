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
        var orbit: CGFloat
        var angle: CGFloat
        var size: CGFloat
        var color: Color
    }

    private let planets: [PlanetSpec] = [
        PlanetSpec(orbit: 0.14, angle: 18, size: 0.010, color: Color(red: 0.67, green: 0.88, blue: 0.97)),
        PlanetSpec(orbit: 0.19, angle: 118, size: 0.012, color: Color(red: 0.92, green: 0.61, blue: 0.42)),
        PlanetSpec(orbit: 0.24, angle: 245, size: 0.013, color: Color(red: 0.97, green: 0.74, blue: 0.44)),
        PlanetSpec(orbit: 0.29, angle: 312, size: 0.014, color: Color(red: 0.57, green: 0.75, blue: 0.93)),
        PlanetSpec(orbit: 0.36, angle: 76, size: 0.015, color: Color(red: 0.63, green: 0.83, blue: 0.95)),
        PlanetSpec(orbit: 0.43, angle: 188, size: 0.016, color: Color(red: 0.94, green: 0.66, blue: 0.49)),
        PlanetSpec(orbit: 0.52, angle: 134, size: 0.018, color: Color(red: 0.89, green: 0.56, blue: 0.36)),
        PlanetSpec(orbit: 0.60, angle: 286, size: 0.017, color: Color(red: 0.66, green: 0.81, blue: 0.95)),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width * 0.82, y: proxy.size.height * 0.80)
            let orbitFractions: [CGFloat] = [0.34, 0.49, 0.64, 0.79]

            ZStack {
                ForEach(Array(orbitFractions.enumerated()), id: \.offset) { index, fraction in
                    Circle()
                        .stroke(
                            Color(red: 0.58, green: 0.84, blue: 0.95)
                                .opacity(0.05 + Double(index) * 0.03),
                            lineWidth: 0.8
                        )
                        .frame(width: size * fraction * 2, height: size * fraction * 2)
                        .position(center)
                }

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
