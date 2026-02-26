import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class FloatingPalettePanelController {
    private var panel: NSPanel?

    func show(store: StoreOf<AppFeature>) {
        if panel == nil {
            let contentView = FloatingPaletteHostView(store: store)
            let hostingView = NSHostingView(rootView: contentView)

            let initialRect = NSRect(x: 200, y: 200, width: 320, height: 160)
            let panel = NSPanel(
                contentRect: initialRect,
                styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.contentView = hostingView

            self.panel = panel
        }

        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func pinToEdge() {
        guard let panel, let screenFrame = panel.screen?.visibleFrame else { return }

        let panelFrame = panel.frame
        let leftDistance = abs(panelFrame.minX - screenFrame.minX)
        let rightDistance = abs(screenFrame.maxX - panelFrame.maxX)

        let targetX: CGFloat
        if leftDistance <= rightDistance {
            targetX = screenFrame.minX + 8
        } else {
            targetX = screenFrame.maxX - panelFrame.width - 8
        }

        let maxY = screenFrame.maxY - panelFrame.height - 8
        let minY = screenFrame.minY + 8
        let clampedY = min(max(panelFrame.origin.y, minY), maxY)

        panel.setFrameOrigin(NSPoint(x: targetX, y: clampedY))
    }
}

private struct FloatingPaletteHostView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        if let paletteStore = store.scope(
            state: \.floatingPalette,
            action: \.floatingPalette.presented
        ) {
            FloatingPaletteView(store: paletteStore)
        } else {
            Color.clear
                .frame(width: 320, height: 160)
        }
    }
}
