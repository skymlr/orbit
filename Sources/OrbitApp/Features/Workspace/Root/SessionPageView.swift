import ComposableArchitecture
import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

struct SessionPageView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    @State private var isHistoryMode = false
    @State private var selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: Date())
    @State private var selectedHistorySessionID: UUID?
    @State private var isHistoryCalendarPresented = false
    @State private var isExportAllConfirmationPresented = false
    @State private var isHistorySearchPresented = false
    @StateObject private var historySearchModel = HistorySearchPanelModel()
#if os(macOS)
    @State private var historySearchPanelController = HistorySearchPanelController()
#endif

    var body: some View {
        contentView
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .padding(.top, contentTopPadding)
#if os(macOS)
        .frame(minWidth: 760, idealWidth: 1_180, minHeight: 680, idealHeight: 760)
#endif
#if os(iOS)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            sessionToolbarContent
        }
        .confirmationDialog(
            "Export All Sessions?",
            isPresented: $isExportAllConfirmationPresented
        ) {
            Button("Export \(completedHistorySessionIDs.count) Session\(completedHistorySessionIDs.count == 1 ? "" : "s")") {
                exportAllSessionsConfirmationAccepted()
            }

            Button("Cancel", role: .cancel) {
                isExportAllConfirmationPresented = false
            }
        } message: {
            Text("Export markdown files for every completed session currently saved in history.")
        }
        .task(id: store.activeSession?.id) {
            reconcileHistorySelection()
            refreshHistorySearchPanelIfNeeded()
        }
        .onChange(of: historyDayGroups) { _, _ in
            reconcileHistorySelection()
            refreshHistorySearchPanelIfNeeded()
        }
        .onChange(of: store.appearance) { _, _ in
            refreshHistorySearchPanelIfNeeded()
        }
        .onChange(of: store.presentation.pendingDirectoryExport?.id) { _, requestID in
            guard requestID != nil else { return }
            presentPendingDirectoryExportIfNeeded()
        }
        .onChange(of: selectedHistoryDay) { _, newDay in
            let normalized = SessionHistoryBrowserSupport.normalizedDay(for: newDay)
            if selectedHistoryDay != normalized {
                selectedHistoryDay = normalized
                return
            }
            selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
                on: normalized,
                groups: historyDayGroups
            )
        }
        .onChange(of: isHistoryMode) { _, isHistoryMode in
            guard !isHistoryMode else { return }
            dismissHistorySearchPanel()
        }
        .onDisappear {
            dismissHistorySearchPanel()
        }
        .animation(.easeInOut(duration: 0.18), value: store.activeSession?.id)
        .animation(.easeInOut(duration: 0.16), value: isHistoryMode)
    }

    private var contentTopPadding: CGFloat {
#if os(iOS)
        if isHistoryMode || store.activeSession == nil {
            return 18
        }
        return 0
#else
        if isHistoryMode || store.activeSession == nil {
            return 18
        }
        return 0
#endif
    }

    @ViewBuilder
    private var contentView: some View {
        if isHistoryMode {
            historyModeContent
        } else {
            SessionLiveView(store: store)
        }
    }

    @ViewBuilder
    private var historyModeContent: some View {
#if os(iOS)
        if isShowingInlineHistorySearchResults {
            HistorySearchView(model: historySearchModel)
                .searchable(text: $historySearchModel.query, placement: .toolbar, prompt: "Search history")
        } else {
            sessionHistoryContent
                .searchable(text: $historySearchModel.query, placement: .toolbar, prompt: "Search history")
        }
#else
        sessionHistoryContent
#endif
    }

    private var sessionHistoryContent: some View {
        SessionHistoryView(
            store: store,
            historyDayGroups: historyDayGroups,
            selectedHistoryDay: selectedHistoryDay,
            selectedHistorySessionID: selectedHistorySessionID,
            onExitHistoryMode: exitHistoryMode,
            onSelectHistorySession: selectHistorySession(_:),
            onExportSession: exportSessionButtonTapped(sessionID:)
        )
    }

    @ToolbarContentBuilder
    private var sessionToolbarContent: some ToolbarContent {
#if os(macOS)
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                store.send(.sessionAddTaskTapped)
            } label: {
                Image(systemName: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .help("Capture Task \(HotkeyHintFormatter.hint(from: store.hotkeys.captureShortcut))")

            Button {
                openHistoryCalendarButtonTapped()
            } label: {
                Image(systemName: "calendar")
            }
            .help("Browse session history by day")
            .popover(isPresented: $isHistoryCalendarPresented, arrowEdge: .bottom) {
                historyCalendarPopover
            }

            if isHistoryMode {
                Button {
                    navigateToPreviousHistoryDayButtonTapped()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(previousHistoryDay == nil)
                .help("Older session day")

                Button {
                    navigateToNextHistoryDayButtonTapped()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(nextHistoryDay == nil)
                .help("Newer session day")

                Button {
                    searchHistoryButtonTapped()
                } label: {
                    Label("Search History", systemImage: "magnifyingglass")
                }
                .help(historySearchButtonHelpText)

                Button {
                    exportAllSessionsToolbarButtonTapped()
                } label: {
                    Label("Export All Sessions", systemImage: "square.and.arrow.up")
                }
                .disabled(completedHistorySessionIDs.isEmpty)
                .help("Export markdown files for all completed sessions")
            }

            SettingsLink {
                Label("Preferences", systemImage: "gearshape")
            }
            .help("Open Settings")
        }
#else
        ToolbarItem(placement: .bottomBar) {
            Button(action: quickCaptureButtonTapped) {
                Label("Add Task", systemImage: "plus")
            }
        }
        
        ToolbarItem(placement: .topBarLeading) {
            Button(action: openPreferencesButtonTapped) {
                Label("Settings", systemImage: "gearshape")
            }
        }

        ToolbarSpacer(.fixed, placement: .topBarLeading)

        ToolbarItem(placement: .topBarLeading) {
            Button(action: openHistoryCalendarButtonTapped) {
                Image(systemName: "calendar")
            }
            .popover(isPresented: $isHistoryCalendarPresented, arrowEdge: .bottom) {
                historyCalendarPopover
            }
        }

        if isHistoryMode && !isShowingInlineHistorySearchResults {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: navigateToPreviousHistoryDayButtonTapped) {
                    Image(systemName: "chevron.left")
                }
                .disabled(previousHistoryDay == nil)

                Button(action: navigateToNextHistoryDayButtonTapped) {
                    Image(systemName: "chevron.right")
                }
                .disabled(nextHistoryDay == nil)
            }
        }
#endif
    }

    private var historyCalendarPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Jump To Day")
                .orbitFont(.headline)

            HistoryCalendarPickerView(
                availableDays: Set(historyDayGroups.map(\.day)),
                selectedDay: selectedHistoryDay,
                onSelectDay: { selectedDay in
                    enterHistoryMode(on: selectedDay)
                    isHistoryCalendarPresented = false
                }
            )
        }
        .padding(12)
    }

    private var historyDayGroups: [HistoryDayGroup] {
        SessionHistoryBrowserSupport.dayGroups(
            from: store.settings.sessions,
            excludingActiveSessionID: store.activeSession?.id
        )
    }

    private var previousHistoryDay: Date? {
        SessionHistoryBrowserSupport.adjacentDay(
            from: selectedHistoryDay,
            groups: historyDayGroups,
            direction: .previous
        )
    }

    private var nextHistoryDay: Date? {
        SessionHistoryBrowserSupport.adjacentDay(
            from: selectedHistoryDay,
            groups: historyDayGroups,
            direction: .next
        )
    }

    private var completedHistorySessionIDs: [UUID] {
        store.settings.sessions
            .filter { $0.endedAt != nil }
            .map(\.id)
    }

#if os(iOS)
    private var isShowingInlineHistorySearchResults: Bool {
        !trimmedHistorySearchQuery.isEmpty
    }

    private var navigationTitle: String {
        if isHistoryMode {
            return SessionHistoryBrowserSupport.dayLabel(selectedHistoryDay)
        }
        return ""
    }

    private var trimmedHistorySearchQuery: String {
        historySearchModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
#endif

    private func selectHistorySession(_ sessionID: UUID) {
        selectedHistorySessionID = sessionID
    }

    private func quickCaptureButtonTapped() {
        if store.activeSession == nil {
            store.send(.captureTapped)
        } else {
            store.send(.sessionAddTaskTapped)
        }
    }

    private func openPreferencesButtonTapped() {
        store.send(.openPreferencesTapped)
    }

    private func openHistoryCalendarButtonTapped() {
        isHistoryCalendarPresented = true
    }

    private func exportAllSessionsToolbarButtonTapped() {
        guard !completedHistorySessionIDs.isEmpty else { return }
        isExportAllConfirmationPresented = true
    }

    private func exportAllSessionsConfirmationAccepted() {
        guard !completedHistorySessionIDs.isEmpty else { return }
        store.send(.exportAllButtonTapped)
    }

    private func exportSessionButtonTapped(sessionID: UUID) {
        store.send(.exportSessionButtonTapped(sessionID))
    }

#if os(macOS)
    private func chooseExportDirectory(_ onURLSelected: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"

        if panel.runModal() == .OK, let url = panel.url {
            onURLSelected(url)
        }
    }
#endif

    private func enterHistoryMode(on day: Date) {
        clearHistorySearch()
        isHistoryMode = true
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
    }

    private func exitHistoryMode() {
        dismissHistorySearchPanel()
        clearHistorySearch()
        isHistoryMode = false
    }

    private func navigateHistoryDay(_ direction: HistoryDayNavigationDirection) {
        guard let nextDay = SessionHistoryBrowserSupport.adjacentDay(
            from: selectedHistoryDay,
            groups: historyDayGroups,
            direction: direction
        ) else {
            return
        }

        selectedHistoryDay = nextDay
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: nextDay,
            groups: historyDayGroups
        )
    }

    private func navigateToPreviousHistoryDayButtonTapped() {
        navigateHistoryDay(.previous)
    }

    private func navigateToNextHistoryDayButtonTapped() {
        navigateHistoryDay(.next)
    }

    private func reconcileHistorySelection() {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: selectedHistoryDay)
        selectedHistorySessionID = SessionHistoryBrowserSupport.resolveSelectedSession(
            id: selectedHistorySessionID,
            on: selectedHistoryDay,
            groups: historyDayGroups
        )?.id
    }

    private func searchHistoryButtonTapped() {
        guard isHistoryMode else { return }

        let shouldResetSearch = !isHistorySearchPresented
        configureHistorySearchModel(resetSearch: shouldResetSearch)
        isHistorySearchPresented = true
#if os(macOS)
        historySearchPanelController.present(
            configuration: historySearchPanelConfiguration(),
            resetSearch: shouldResetSearch
        )
#endif
    }

    private func dismissHistorySearchPanel() {
        guard isHistorySearchPresented else { return }
        isHistorySearchPresented = false
#if os(macOS)
        historySearchPanelController.dismiss()
#endif
    }

    private func refreshHistorySearchPanelIfNeeded() {
        configureHistorySearchModel(resetSearch: false)
#if os(macOS)
        guard isHistorySearchPresented else { return }
        historySearchPanelController.refresh(configuration: historySearchPanelConfiguration())
#endif
    }

    private func historySearchPanelConfiguration() -> HistorySearchPanelConfiguration {
        HistorySearchPanelConfiguration(
            sessions: store.settings.sessions,
            excludingActiveSessionID: store.activeSession?.id,
            appearance: store.appearance,
            onGoToDay: navigateToHistoryDayFromSearch(_:),
            onGoToSession: navigateToHistorySessionFromSearch(day:sessionID:),
            onClose: {
                isHistorySearchPresented = false
            }
        )
    }

    private var historySearchButtonHelpText: String {
#if os(macOS)
        "Open floating history search"
#else
        "Open history search"
#endif
    }

    private func configureHistorySearchModel(resetSearch: Bool) {
        let configuration = historySearchPanelConfiguration()
        historySearchModel.sessions = configuration.sessions
        historySearchModel.excludingActiveSessionID = configuration.excludingActiveSessionID
        historySearchModel.appearance = configuration.appearance
        historySearchModel.onGoToDayRequested = { day in
            configuration.onGoToDay(day)
        }
        historySearchModel.onGoToSessionRequested = { session in
            configuration.onGoToSession(session.startedAt, session.id)
        }
        historySearchModel.onCloseRequested = {
            configuration.onClose()
        }

        if resetSearch {
            historySearchModel.resetSearch()
        }
    }

    private func presentPendingDirectoryExportIfNeeded() {
#if os(macOS)
        guard store.presentation.pendingDirectoryExport != nil else { return }
        chooseExportDirectory { url in
            store.send(.exportDirectorySelected(url))
        }
        if store.presentation.pendingDirectoryExport != nil {
            store.send(.exportDirectorySelectionCancelled)
        }
#endif
    }

    private func navigateToHistoryDayFromSearch(_ day: Date) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
        clearHistorySearch()
    }

    private func navigateToHistorySessionFromSearch(day: Date, sessionID: UUID) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = sessionID
        clearHistorySearch()
    }

    private func clearHistorySearch() {
        historySearchModel.resetSearch()
    }
}
