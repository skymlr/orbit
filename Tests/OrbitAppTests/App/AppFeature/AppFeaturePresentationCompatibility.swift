import Foundation
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

enum TestWindowDestination: Hashable {
    case workspaceWindow
    case captureWindow
}

extension AppFeature.State {
    var windowDestinations: Set<TestWindowDestination> {
        get {
            var destinations: Set<TestWindowDestination> = []
            if presentation.isWorkspacePresented {
                destinations.insert(.workspaceWindow)
            }
            if presentation.isCapturePresented {
                destinations.insert(.captureWindow)
            }
            return destinations
        }
        set {
            presentation.isWorkspacePresented = newValue.contains(.workspaceWindow)
            presentation.isCapturePresented = newValue.contains(.captureWindow)
        }
    }

    var workspaceWindowFocusRequest: Int {
        get { presentation.workspacePresentationRequest }
        set { presentation.workspacePresentationRequest = newValue }
    }

    var captureWindowFocusRequest: Int {
        get { presentation.capturePresentationRequest }
        set { presentation.capturePresentationRequest = newValue }
    }
}
