import SwiftUI

#if os(macOS)
import AppKit
#endif

private struct OrbitAppearanceKey: EnvironmentKey {
    static let defaultValue = AppearanceSettings.default
}

extension EnvironmentValues {
    var orbitAppearance: AppearanceSettings {
        get { self[OrbitAppearanceKey.self] }
        set { self[OrbitAppearanceKey.self] = newValue }
    }
}

extension View {
    func orbitAppearance(_ appearance: AppearanceSettings) -> some View {
        modifier(OrbitAppearanceModifier(appearance: appearance))
    }
}

private struct OrbitAppearanceModifier: ViewModifier {
    let appearance: AppearanceSettings

    func body(content: Content) -> some View {
        content
            .environment(\.orbitAppearance, appearance)
            .font(OrbitTypography.swiftUIFont(.body, appearance: appearance))
            .background {
                OrbitWindowAppearanceConfigurator()
            }
    }
}

private struct OrbitWindowAppearanceConfigurator: View {
    var body: some View {
#if os(macOS)
        OrbitMacWindowAppearanceConfigurator()
#else
        Color.clear.frame(width: 0, height: 0)
#endif
    }
}

#if os(macOS)
private struct OrbitMacWindowAppearanceConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> OrbitWindowAppearanceView {
        OrbitWindowAppearanceView()
    }

    func updateNSView(_ nsView: OrbitWindowAppearanceView, context: Context) {
        nsView.applyWindowAppearanceIfNeeded()
    }
}

private final class OrbitWindowAppearanceView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWindowAppearanceIfNeeded()
    }

    func applyWindowAppearanceIfNeeded() {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        if window.styleMask.contains(.titled) {
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
        }

        window.invalidateShadow()
    }
}
#endif
