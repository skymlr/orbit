import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct OrbitTypographyTests {
    @Test
    func customFontFallsBackToSystemFontWhenLookupFails() {
        let expected = OrbitTypography.appKitFont(
            size: 14,
            weight: OrbitPlatformFontWeight.semibold,
            appearance: .default
        )

        let fallback = OrbitTypography.appKitFont(
            size: 14,
            weight: OrbitPlatformFontWeight.semibold,
            appearance: AppearanceSettings(
                font: .geist,
                background: .spaceBlue,
                showsOrbitalLayer: true
            ),
            fontLookup: { _, _ in nil }
        )

        #expect(fallback.fontName == expected.fontName)
        #expect(fallback.pointSize == expected.pointSize)
    }
}
