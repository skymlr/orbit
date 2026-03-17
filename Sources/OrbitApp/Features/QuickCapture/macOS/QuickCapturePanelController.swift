#if os(macOS)
import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class QuickCapturePanelController {
    static let shared = QuickCapturePanelController()

    private enum Layout {
        static let width: CGFloat = 480
        static let height: CGFloat = 320
        static let bottomInset: CGFloat = 36
    }

    private var panel: OrbitQuickCapturePanel?
    private var hostingController: NSHostingController<QuickCapturePanelRootView>?
    // Reset reused SwiftUI state after the panel is hidden.
    private var captureViewResetToken = 0

    private init() {}

    func present(store: StoreOf<AppFeature>) {
        let panel = ensurePanel(store: store)
        updateRootView(store: store)
        panel.onEscape = {
            store.send(.captureWindowClosed)
        }
        position(panel: panel)
        NSApplication.shared.activate(ignoringOtherApps: true)
        promotePanelToFront(panel)
        DispatchQueue.main.async { [weak panel] in
            guard let panel else { return }
            self.promotePanelToFront(panel)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak panel] in
            guard let panel else { return }
            self.promotePanelToFront(panel)
        }
    }

    func dismiss() {
        captureViewResetToken &+= 1
        panel?.orderOut(nil)
    }

    private func ensurePanel(store: StoreOf<AppFeature>) -> OrbitQuickCapturePanel {
        if let panel {
            return panel
        }

        let panel = OrbitQuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onEscape = {
            store.send(.captureWindowClosed)
        }

        self.panel = panel
        return panel
    }

    private func updateRootView(store: StoreOf<AppFeature>) {
        let rootView = QuickCapturePanelRootView(
            store: store,
            resetToken: captureViewResetToken
        )

        if let hostingController {
            hostingController.rootView = rootView
            return
        }

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear
        panel?.contentViewController = hostingController
        self.hostingController = hostingController
    }

    private func position(panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSApplication.shared.keyWindow?.screen
            ?? NSApplication.shared.mainWindow?.screen
            ?? NSScreen.main
        let frame = targetScreen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero

        let x = frame.midX - (Layout.width / 2)
        let y = frame.minY + Layout.bottomInset
        panel.setFrame(NSRect(x: x, y: y, width: Layout.width, height: Layout.height), display: true)
    }

    private func promotePanelToFront(_ panel: NSPanel) {
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeMain()
    }
}

private final class OrbitQuickCapturePanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

private struct QuickCapturePanelRootView: View {
    let store: StoreOf<AppFeature>
    let resetToken: Int

    var body: some View {
        QuickCaptureView(store: store)
            .id(resetToken)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .orbitAppearance(store.appearance)
            .preferredColorScheme(.dark)
            .orbitOnExitCommand {
                store.send(.captureWindowClosed)
            }
    }
}
#endif
