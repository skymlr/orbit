import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class QuickCapturePanelController {
    static let shared = QuickCapturePanelController()

    private enum Layout {
        static let width: CGFloat = 480
        static let height: CGFloat = 520
        static let bottomInset: CGFloat = 36
    }

    private var panel: OrbitQuickCapturePanel?
    private var hostingController: NSHostingController<QuickCapturePanelRootView>?

    private init() {}

    func present(store: StoreOf<AppFeature>) {
        let panel = ensurePanel(store: store)
        updateRootView(store: store)
        panel.onEscape = {
            store.send(.captureWindowClosed)
        }
        position(panel: panel)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
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
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onEscape = {
            store.send(.captureWindowClosed)
        }

        self.panel = panel
        return panel
    }

    private func updateRootView(store: StoreOf<AppFeature>) {
        let rootView = QuickCapturePanelRootView(store: store)

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
        let targetScreen = NSApplication.shared.keyWindow?.screen
            ?? NSApplication.shared.mainWindow?.screen
            ?? NSScreen.main
        let frame = targetScreen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero

        let x = frame.midX - (Layout.width / 2)
        let y = frame.minY + Layout.bottomInset
        panel.setFrame(NSRect(x: x, y: y, width: Layout.width, height: Layout.height), display: true)
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

    var body: some View {
        QuickCaptureView(store: store)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onExitCommand {
                store.send(.captureWindowClosed)
            }
    }
}
