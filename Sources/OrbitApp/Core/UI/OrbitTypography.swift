import AppKit
import SwiftUI

enum OrbitTypography {
    static func swiftUIFont(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        appearance: AppearanceSettings,
        monospaced: Bool = false,
        monospacedDigits: Bool = false
    ) -> Font {
        Font(
            appKitFont(
                style,
                weight: weight.map(nsFontWeight(for:)),
                appearance: appearance,
                monospaced: monospaced,
                monospacedDigits: monospacedDigits
            )
        )
    }

    static func swiftUIFont(
        size: CGFloat,
        weight: Font.Weight? = nil,
        design: Font.Design? = nil,
        appearance: AppearanceSettings,
        monospaced: Bool = false,
        monospacedDigits: Bool = false,
        fontLookup: (String, CGFloat) -> NSFont? = OrbitFontRegistry.font(named:size:)
    ) -> Font {
        Font(
            appKitFont(
                size: size,
                weight: weight.map(nsFontWeight(for:)) ?? .regular,
                design: design.map(nsFontDesign(for:)),
                appearance: appearance,
                monospaced: monospaced,
                monospacedDigits: monospacedDigits,
                fontLookup: fontLookup
            )
        )
    }

    static func appKitFont(
        _ style: Font.TextStyle,
        weight: NSFont.Weight? = nil,
        appearance: AppearanceSettings,
        monospaced: Bool = false,
        monospacedDigits: Bool = false,
        fontLookup: (String, CGFloat) -> NSFont? = OrbitFontRegistry.font(named:size:)
    ) -> NSFont {
        let textStyle = nsTextStyle(for: style)
        let preferredFont = NSFont.preferredFont(forTextStyle: textStyle)
        return appKitFont(
            size: preferredFont.pointSize,
            weight: weight ?? .regular,
            appearance: appearance,
            monospaced: monospaced,
            monospacedDigits: monospacedDigits,
            fontLookup: fontLookup
        )
    }

    static func appKitFont(
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        design: NSFontDescriptor.SystemDesign? = nil,
        appearance: AppearanceSettings,
        monospaced: Bool = false,
        monospacedDigits: Bool = false,
        fontLookup: (String, CGFloat) -> NSFont? = OrbitFontRegistry.font(named:size:)
    ) -> NSFont {
        if monospaced {
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
        if monospacedDigits {
            return NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        }

        OrbitFontRegistry.registerBundledFonts()

        if let postScriptName = postScriptName(for: appearance.font, weight: weight),
           let customFont = fontLookup(postScriptName, size)
        {
            return customFont
        }

        return systemFont(
            size: size,
            weight: weight,
            design: design
        )
    }

    static func previewFont(
        for option: OrbitFontOption,
        style: Font.TextStyle,
        weight: Font.Weight = .regular
    ) -> Font {
        swiftUIFont(
            style,
            weight: weight,
            appearance: AppearanceSettings(font: option, background: .orbit)
        )
    }

    private static func systemFont(
        size: CGFloat,
        weight: NSFont.Weight,
        design: NSFontDescriptor.SystemDesign? = nil
    ) -> NSFont {
        let baseFont = NSFont.systemFont(ofSize: size, weight: weight)
        guard let design else { return baseFont }
        guard let descriptor = baseFont.fontDescriptor.withDesign(design),
              let designedFont = NSFont(descriptor: descriptor, size: size)
        else {
            return baseFont
        }
        return designedFont
    }

    private static func postScriptName(for option: OrbitFontOption, weight: NSFont.Weight) -> String? {
        switch option {
        case .system:
            return nil
        case .geist:
            switch weightBucket(for: weight) {
            case .regular:
                return "Geist-Regular"
            case .semibold:
                return "Geist-SemiBold"
            case .bold:
                return "Geist-Bold"
            }
        case .sourceSerif4:
            switch weightBucket(for: weight) {
            case .regular:
                return "SourceSerif4-Regular"
            case .semibold:
                return "SourceSerif4-Semibold"
            case .bold:
                return "SourceSerif4-Bold"
            }
        }
    }

    private static func weightBucket(for weight: NSFont.Weight) -> OrbitFontWeightBucket {
        switch weight {
        case ..<NSFont.Weight.semibold:
            return .regular
        case ..<NSFont.Weight.bold:
            return .semibold
        default:
            return .bold
        }
    }

    private static func nsTextStyle(for style: Font.TextStyle) -> NSFont.TextStyle {
        switch style {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .body:
            return .body
        case .callout:
            return .callout
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        default:
            return .body
        }
    }

    private static func nsFontWeight(for weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        default:
            return .regular
        }
    }

    private static func nsFontDesign(for design: Font.Design) -> NSFontDescriptor.SystemDesign {
        switch design {
        case .default:
            return .default
        case .serif:
            return .serif
        case .rounded:
            return .rounded
        case .monospaced:
            return .monospaced
        @unknown default:
            return .default
        }
    }
}

private enum OrbitFontWeightBucket {
    case regular
    case semibold
    case bold
}

private struct OrbitFontModifier: ViewModifier {
    @Environment(\.orbitAppearance) private var appearance

    let style: Font.TextStyle
    let weight: Font.Weight?
    let monospaced: Bool
    let monospacedDigits: Bool

    func body(content: Content) -> some View {
        content.font(
            OrbitTypography.swiftUIFont(
                style,
                weight: weight,
                appearance: appearance,
                monospaced: monospaced,
                monospacedDigits: monospacedDigits
            )
        )
    }
}

private struct OrbitSizedFontModifier: ViewModifier {
    @Environment(\.orbitAppearance) private var appearance

    let size: CGFloat
    let weight: Font.Weight?
    let design: Font.Design?
    let monospaced: Bool
    let monospacedDigits: Bool

    func body(content: Content) -> some View {
        content.font(
            OrbitTypography.swiftUIFont(
                size: size,
                weight: weight,
                design: design,
                appearance: appearance,
                monospaced: monospaced,
                monospacedDigits: monospacedDigits
            )
        )
    }
}

extension View {
    func orbitFont(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        monospaced: Bool = false,
        monospacedDigits: Bool = false
    ) -> some View {
        modifier(
            OrbitFontModifier(
                style: style,
                weight: weight,
                monospaced: monospaced,
                monospacedDigits: monospacedDigits
            )
        )
    }

    func orbitFont(
        size: CGFloat,
        weight: Font.Weight? = nil,
        design: Font.Design? = nil,
        monospaced: Bool = false,
        monospacedDigits: Bool = false
    ) -> some View {
        modifier(
            OrbitSizedFontModifier(
                size: size,
                weight: weight,
                design: design,
                monospaced: monospaced,
                monospacedDigits: monospacedDigits
            )
        )
    }
}
