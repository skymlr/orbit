#if os(macOS)
import AppKit
import ComposableArchitecture
import SwiftUI

enum OrbitWindowID {
    static let workspace = "workspace-window"
}

struct WindowStateCoordinator: View {
    let store: StoreOf<AppFeature>

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                syncWorkspacePresentation(isPresented: store.presentation.isWorkspacePresented)
                syncCapturePresentation(isPresented: store.presentation.isCapturePresented)
            }
            .onChange(of: store.presentation.isWorkspacePresented) { _, isPresented in
                syncWorkspacePresentation(isPresented: isPresented)
            }
            .onChange(of: store.presentation.isCapturePresented) { _, isPresented in
                syncCapturePresentation(isPresented: isPresented)
            }
            .onChange(of: store.presentation.workspacePresentationRequest) { _, _ in
                guard store.presentation.isWorkspacePresented else { return }
                openWindow(id: OrbitWindowID.workspace)
                bringWorkspaceWindowToFront()
            }
            .onChange(of: store.presentation.capturePresentationRequest) { _, _ in
                guard store.presentation.isCapturePresented else { return }
                QuickCapturePanelController.shared.present(store: store)
            }
    }

    private func syncWorkspacePresentation(isPresented: Bool) {
        if isPresented {
            openWindow(id: OrbitWindowID.workspace)
            bringWorkspaceWindowToFront()
        } else {
            dismissWindow(id: OrbitWindowID.workspace)
        }
    }

    private func syncCapturePresentation(isPresented: Bool) {
        if isPresented {
            QuickCapturePanelController.shared.present(store: store)
        } else {
            QuickCapturePanelController.shared.dismiss()
        }
    }

    private func bringWorkspaceWindowToFront() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Orbit: A Focus Manager" }) else {
                return
            }
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
}
#endif
