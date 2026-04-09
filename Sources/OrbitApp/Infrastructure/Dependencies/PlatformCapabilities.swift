import Dependencies
import Foundation

struct PlatformCapabilities: Sendable {
    var supportsGlobalHotkeys: Bool
    var supportsIdleMonitoring: Bool
    var supportsMenuBar: Bool
    var supportsPointerInteractions: Bool
    var usesShareExport: Bool
    var supportsCloudSync: Bool
}

extension PlatformCapabilities: DependencyKey {
    static var liveValue: PlatformCapabilities {
#if LOCAL_UNSIGNED
        let supportsCloudSync = false
#else
        let supportsCloudSync = true
#endif
#if os(macOS)
        return PlatformCapabilities(
            supportsGlobalHotkeys: true,
            supportsIdleMonitoring: true,
            supportsMenuBar: true,
            supportsPointerInteractions: true,
            usesShareExport: false,
            supportsCloudSync: supportsCloudSync
        )
#else
        return PlatformCapabilities(
            supportsGlobalHotkeys: false,
            supportsIdleMonitoring: false,
            supportsMenuBar: false,
            supportsPointerInteractions: false,
            usesShareExport: true,
            supportsCloudSync: supportsCloudSync
        )
#endif
    }

    static var testValue: PlatformCapabilities {
        PlatformCapabilities(
            supportsGlobalHotkeys: false,
            supportsIdleMonitoring: false,
            supportsMenuBar: false,
            supportsPointerInteractions: false,
            usesShareExport: false,
            supportsCloudSync: true
        )
    }
}

extension DependencyValues {
    var platformCapabilities: PlatformCapabilities {
        get { self[PlatformCapabilities.self] }
        set { self[PlatformCapabilities.self] = newValue }
    }
}
