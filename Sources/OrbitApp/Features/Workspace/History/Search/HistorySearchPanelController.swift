import AppKit
import SwiftUI

struct HistorySearchPanelConfiguration {
    let sessions: [FocusSessionRecord]
    let excludingActiveSessionID: UUID?
    let appearance: AppearanceSettings
    let onGoToDay: (Date) -> Void
    let onGoToSession: (Date, UUID) -> Void
    let onClose: () -> Void
}

@MainActor
final class HistorySearchPanelModel: ObservableObject {
    @Published var query = ""
    @Published var filter: HistoryTaskFilter = .all
    @Published var sessions: [FocusSessionRecord] = []
    @Published var excludingActiveSessionID: UUID?
    @Published var appearance: AppearanceSettings = .default
    var onGoToDayRequested: (Date) -> Void = { _ in }
    var onGoToSessionRequested: (FocusSessionRecord) -> Void = { _ in }
    var onCloseRequested: () -> Void = {}

    func resetSearch() {
        query = ""
        filter = .all
    }

    func goToDay(_ day: Date) {
        onGoToDayRequested(day)
    }

    func goToSession(_ session: FocusSessionRecord) {
        onGoToSessionRequested(session)
    }

    func closeRequested() {
        onCloseRequested()
    }
}

@MainActor
final class HistorySearchPanelController: NSObject, NSWindowDelegate, NSToolbarDelegate, NSSearchFieldDelegate {
    private enum Layout {
        static let width: CGFloat = 780
        static let height: CGFloat = 620
        static let minWidth: CGFloat = 620
        static let minHeight: CGFloat = 480
    }

    private let model = HistorySearchPanelModel()
    private let toolbarIdentifier = NSToolbar.Identifier("orbit.historySearchToolbar")
    private let searchItemIdentifier = NSToolbarItem.Identifier("orbit.historySearchToolbar.search")

    private var panel: OrbitHistorySearchPanel?
    private var hostingController: NSHostingController<HistorySearchPanelRootView>?
    private var searchToolbarItem: NSSearchToolbarItem?
    private var attachedParentWindow: NSWindow?
    private var onClose: () -> Void = {}
    private var escapeMonitor: Any?

    func present(configuration: HistorySearchPanelConfiguration, resetSearch: Bool) {
        configureModel(with: configuration, resetSearch: resetSearch)

        let panel = ensurePanel()
        updateRootView()
        installEscapeMonitorIfNeeded()
        attachPanelIfNeeded(panel)
        position(panel)

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeMain()

        focusSearchFieldSoon()
    }

    func refresh(configuration: HistorySearchPanelConfiguration) {
        guard panel != nil else { return }
        configureModel(with: configuration, resetSearch: false)
    }

    func dismiss() {
        closePanel()
    }

    private func configureModel(with configuration: HistorySearchPanelConfiguration, resetSearch: Bool) {
        onClose = configuration.onClose
        model.sessions = configuration.sessions
        model.excludingActiveSessionID = configuration.excludingActiveSessionID
        model.appearance = configuration.appearance
        model.onGoToDayRequested = { [weak self] day in
            configuration.onGoToDay(day)
            self?.closePanel()
        }
        model.onGoToSessionRequested = { [weak self] session in
            configuration.onGoToSession(session.startedAt, session.id)
            self?.closePanel()
        }
        model.onCloseRequested = { [weak self] in
            self?.closePanel()
        }

        if resetSearch {
            model.resetSearch()
        }
        syncSearchFieldFromModel()
    }

    private func ensurePanel() -> OrbitHistorySearchPanel {
        if let panel {
            return panel
        }

        let panel = OrbitHistorySearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.height),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Search History"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: Layout.minWidth, height: Layout.minHeight)
        panel.delegate = self
        panel.toolbar = makeToolbar()
        panel.toolbarStyle = .unifiedCompact

        self.panel = panel
        installEscapeMonitorIfNeeded()
        return panel
    }

    private func updateRootView() {
        let rootView = HistorySearchPanelRootView(model: model)

        if let hostingController {
            hostingController.rootView = rootView
            return
        }

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel?.contentViewController = hostingController
        self.hostingController = hostingController
    }

    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.showsBaselineSeparator = false
        return toolbar
    }

    private func attachPanelIfNeeded(_ panel: NSPanel) {
        let parentWindow = currentWorkspaceWindow()

        guard let parentWindow else {
            attachedParentWindow = nil
            return
        }

        guard attachedParentWindow !== parentWindow else { return }

        if let attachedParentWindow {
            attachedParentWindow.removeChildWindow(panel)
        }

        parentWindow.addChildWindow(panel, ordered: .above)
        attachedParentWindow = parentWindow
    }

    private func position(_ panel: NSPanel) {
        if let parentWindow = currentWorkspaceWindow() {
            let frame = parentWindow.frame
            let origin = NSPoint(
                x: frame.midX - (Layout.width / 2),
                y: frame.midY - (Layout.height / 2)
            )
            panel.setFrame(
                NSRect(origin: origin, size: NSSize(width: Layout.width, height: Layout.height)),
                display: true
            )
            return
        }

        panel.center()
    }

    private func currentWorkspaceWindow() -> NSWindow? {
        let visibleWindows = NSApplication.shared.windows.filter { window in
            window.isVisible && !(window is NSPanel)
        }

        if let keyWindow = visibleWindows.first(where: { $0 === NSApplication.shared.keyWindow }) {
            return keyWindow
        }
        if let mainWindow = visibleWindows.first(where: { $0 === NSApplication.shared.mainWindow }) {
            return mainWindow
        }
        return visibleWindows.first
    }

    private func focusSearchFieldSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.focusSearchField()
        }
    }

    private func focusSearchField() {
        guard let panel, let searchField = searchToolbarItem?.searchField else { return }
        panel.makeFirstResponder(searchField)
        searchField.currentEditor()?.selectedRange = NSRange(location: searchField.stringValue.count, length: 0)
    }

    private func syncSearchFieldFromModel() {
        guard let searchField = searchToolbarItem?.searchField else { return }
        let font = OrbitTypography.appKitFont(.body, appearance: model.appearance)
        applySearchFieldTypography(searchField, font: font)
        if searchField.stringValue != model.query {
            searchField.stringValue = model.query
        }
    }

    private func installEscapeMonitorIfNeeded() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow else { return event }
            guard event.keyCode == 53 else { return event }
            self.closePanel()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    private func closePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.close()
        } else {
            onClose()
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let panel, let attachedParentWindow {
            attachedParentWindow.removeChildWindow(panel)
        }
        attachedParentWindow = nil
        removeEscapeMonitor()
        onClose()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [searchItemIdentifier, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, searchItemIdentifier]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == searchItemIdentifier else { return nil }

        let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Search History"
        item.searchField.placeholderString = "Search history"
        item.searchField.sendsSearchStringImmediately = true
        item.searchField.delegate = self
        item.searchField.stringValue = model.query
        applySearchFieldTypography(
            item.searchField,
            font: OrbitTypography.appKitFont(.body, appearance: model.appearance)
        )
        searchToolbarItem = item
        return item
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        model.query = searchField.stringValue
    }

    private func applySearchFieldTypography(_ searchField: NSSearchField, font: NSFont) {
        if searchField.font?.fontName != font.fontName || searchField.font?.pointSize != font.pointSize {
            searchField.font = font
        }

        let placeholder = searchField.placeholderString ?? "Search history"
        searchField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }
}

private final class OrbitHistorySearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct HistorySearchPanelRootView: View {
    @ObservedObject var model: HistorySearchPanelModel

    var body: some View {
        ZStack {
            OrbitSpaceBackground()

            HistorySearchView(model: model)
                .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .orbitAppearance(model.appearance)
        .preferredColorScheme(.dark)
    }
}
