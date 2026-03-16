import Dependencies
import Foundation
import IOKit

struct InactivityClient: Sendable {
    var idleDuration: @Sendable () -> TimeInterval
}

extension InactivityClient: DependencyKey {
    static var liveValue: InactivityClient {
        InactivityClient(
            idleDuration: {
                systemIdleDuration()
            }
        )
    }

    static var testValue: InactivityClient {
        InactivityClient(
            idleDuration: { 0 }
        )
    }
}

extension DependencyValues {
    var inactivityClient: InactivityClient {
        get { self[InactivityClient.self] }
        set { self[InactivityClient.self] = newValue }
    }
}

private func systemIdleDuration() -> TimeInterval {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
    guard service != 0 else { return 0 }
    defer { IOObjectRelease(service) }

    var properties: Unmanaged<CFMutableDictionary>?
    let status = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
    guard status == KERN_SUCCESS, let dictionary = properties?.takeRetainedValue() as? [String: Any] else {
        return 0
    }

    guard let idleTime = dictionary["HIDIdleTime"] as? NSNumber else {
        return 0
    }

    return TimeInterval(idleTime.uint64Value) / 1_000_000_000
}
