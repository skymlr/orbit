import Dependencies
import Foundation

struct PlatformCapabilities: Sendable {
    var supportsGlobalHotkeys: Bool
    var supportsIdleMonitoring: Bool
    var supportsMenuBar: Bool
    var supportsPointerInteractions: Bool
    var usesShareExport: Bool
}

extension PlatformCapabilities: DependencyKey {
    static var liveValue: PlatformCapabilities {
#if os(macOS)
        PlatformCapabilities(
            supportsGlobalHotkeys: true,
            supportsIdleMonitoring: true,
            supportsMenuBar: true,
            supportsPointerInteractions: true,
            usesShareExport: false
        )
#else
        PlatformCapabilities(
            supportsGlobalHotkeys: false,
            supportsIdleMonitoring: false,
            supportsMenuBar: false,
            supportsPointerInteractions: false,
            usesShareExport: true
        )
#endif
    }

    static var testValue: PlatformCapabilities {
        PlatformCapabilities(
            supportsGlobalHotkeys: false,
            supportsIdleMonitoring: false,
            supportsMenuBar: false,
            supportsPointerInteractions: false,
            usesShareExport: false
        )
    }
}

extension DependencyValues {
    var platformCapabilities: PlatformCapabilities {
        get { self[PlatformCapabilities.self] }
        set { self[PlatformCapabilities.self] = newValue }
    }
}
