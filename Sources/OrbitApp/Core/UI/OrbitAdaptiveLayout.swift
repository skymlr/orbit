import SwiftUI

enum OrbitAdaptiveLayoutStyle: Equatable {
    case compact
    case regular

    var isCompact: Bool {
        self == .compact
    }
}

struct OrbitAdaptiveLayoutValue: Equatable {
    var style: OrbitAdaptiveLayoutStyle
    var availableWidth: CGFloat

    static let regular = OrbitAdaptiveLayoutValue(
        style: .regular,
        availableWidth: 1_024
    )

    init(style: OrbitAdaptiveLayoutStyle, availableWidth: CGFloat) {
        self.style = style
        self.availableWidth = availableWidth
    }

    init(horizontalSizeClass: UserInterfaceSizeClass?, width: CGFloat) {
#if os(iOS)
        if horizontalSizeClass == .compact || width < 520 {
            self.style = .compact
        } else {
            self.style = .regular
        }
#else
        self.style = .regular
#endif
        self.availableWidth = width
    }

    var isCompact: Bool {
        style.isCompact
    }
}

private struct OrbitAdaptiveLayoutKey: EnvironmentKey {
    static let defaultValue = OrbitAdaptiveLayoutValue.regular
}

extension EnvironmentValues {
    var orbitAdaptiveLayout: OrbitAdaptiveLayoutValue {
        get { self[OrbitAdaptiveLayoutKey.self] }
        set { self[OrbitAdaptiveLayoutKey.self] = newValue }
    }
}

struct OrbitAdaptiveLayoutReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let content: (OrbitAdaptiveLayoutValue) -> Content

    init(@ViewBuilder content: @escaping (OrbitAdaptiveLayoutValue) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = OrbitAdaptiveLayoutValue(
                horizontalSizeClass: horizontalSizeClass,
                width: proxy.size.width
            )

            content(layout)
                .environment(\.orbitAdaptiveLayout, layout)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .topLeading
                )
        }
    }
}
