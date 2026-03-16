import AppKit
import CoreText
import Foundation

enum OrbitFontRegistry {
    private static let fontFileNames = [
        "Geist-Regular",
        "Geist-SemiBold",
        "Geist-Bold",
        "SourceSerif4-Regular",
        "SourceSerif4-Semibold",
        "SourceSerif4-Bold",
    ]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var hasRegisteredBundledFonts = false

    static func registerBundledFonts() {
        lock.lock()
        defer { lock.unlock() }

        guard !hasRegisteredBundledFonts else { return }
        hasRegisteredBundledFonts = true

        for url in bundledFontURLs() {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func font(named postScriptName: String, size: CGFloat) -> NSFont? {
        NSFont(name: postScriptName, size: size)
    }

    private static func bundledFontURLs(bundle: Bundle = orbitResourceBundle) -> [URL] {
        fontFileNames.compactMap { fileName in
            bundle.url(forResource: fileName, withExtension: "ttf", subdirectory: "Fonts")
                ?? bundle.url(forResource: fileName, withExtension: "ttf")
        }
    }
}

private var orbitResourceBundle: Bundle {
#if SWIFT_PACKAGE
    Bundle.module
#else
    Bundle.main
#endif
}
