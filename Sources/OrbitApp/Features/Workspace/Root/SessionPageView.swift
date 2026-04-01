import ComposableArchitecture
import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import AppKit
#endif

private enum SessionPageMode: Equatable {
    case live
    case history
    case search
}

struct SessionPageView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.orbitAdaptiveLayout) private var layout

    @State private var pageMode: SessionPageMode = .live
    @State private var searchReturnMode: SessionPageMode = .live
    @State private var selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: Date())
    @State private var selectedHistorySessionID: UUID?
    @State private var isHistoryCalendarPresented = false
    @State private var isExportAllConfirmationPresented = false
    @StateObject private var searchModel = SessionUnifiedSearchModel()
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, horizontalContentPadding)
            .padding(.bottom, bottomContentPadding)
            .padding(.top, contentTopPadding)
#if os(iOS)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                sessionToolbarContent
            }
#if os(macOS)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .toolbarColorScheme(.dark, for: .windowToolbar)
#endif
            .applyUnifiedToolbarSearch(
                isEnabled: usesToolbarUnifiedSearchField,
                query: $searchModel.query,
                isSearchFieldFocused: $isSearchFieldFocused
            )
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
                configureSearchModel()
            }
            .onChange(of: historyDayGroups) { _, _ in
                reconcileHistorySelection()
                configureSearchModel()
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

                let resolvedSession = SessionHistoryBrowserSupport.resolveSelectedSession(
                    id: selectedHistorySessionID,
                    on: normalized,
                    groups: historyDayGroups
                )
                selectedHistorySessionID = resolvedSession?.id
                    ?? SessionHistoryBrowserSupport.defaultSessionID(
                        on: normalized,
                        groups: historyDayGroups
                    )
            }
            .onChange(of: pageMode) { _, newMode in
                if newMode == .search {
                    focusSearchFieldSoon()
                } else {
                    isSearchFieldFocused = false
                }
            }
            .onChange(of: isSearchFieldFocused) { _, isFocused in
                guard usesToolbarUnifiedSearchField else { return }
                guard isFocused else { return }
                enterSearchModeIfNeeded()
            }
            .onChange(of: searchModel.query) { _, newQuery in
                guard usesToolbarUnifiedSearchField else { return }
                guard !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                enterSearchModeIfNeeded()
            }
            .animation(.easeInOut(duration: 0.18), value: store.activeSession?.id)
            .animation(.easeInOut(duration: 0.16), value: pageMode)
    }

    private var horizontalContentPadding: CGFloat {
        layout.isCompact ? 12 : 18
    }

    private var bottomContentPadding: CGFloat {
        layout.isCompact ? 8 : 18
    }

    private var contentTopPadding: CGFloat {
#if os(iOS)
        if layout.isCompact {
            if pageMode != .live || store.activeSession == nil {
                return 10
            }
            return 4
        }
        if pageMode != .live || store.activeSession == nil {
            return 18
        }
        return 0
#else
        if pageMode != .live || store.activeSession == nil {
            return 18
        }
        return 0
#endif
    }

    @ViewBuilder
    private var contentView: some View {
        switch pageMode {
        case .live:
            SessionLiveView(store: store)

        case .history:
            sessionHistoryContent

        case .search:
            SessionUnifiedSearchContainer(
                store: store,
                model: searchModel,
                showsToolbarSearchField: !usesToolbarUnifiedSearchField,
                isSearchFieldFocused: usesToolbarUnifiedSearchField ? nil : $isSearchFieldFocused
            )
        }
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

            if pageMode == .history {
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

        if pageMode == .search {
            ToolbarSpacer(.fixed, placement: .automatic)
            ToolbarItem(placement: .primaryAction) {
                exitSearchToolbarButton
            }
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

        if pageMode == .history {
            if layout.isCompact {
                ToolbarItem(placement: .topBarTrailing) {
                    historyActionsMenu
                }
            } else {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: navigateToPreviousHistoryDayButtonTapped) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(previousHistoryDay == nil)

                    Button(action: navigateToNextHistoryDayButtonTapped) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(nextHistoryDay == nil)

                    historyActionsMenu
                }
            }
        }

        if usesToolbarUnifiedSearchField {
            if pageMode == .search {
                ToolbarItem(placement: .topBarTrailing) {
                    exitSearchToolbarButton
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                searchToolbarButton
            }
        }
#endif
    }

    private var exitSearchToolbarButton: some View {
        Button(action: handleSearchExitRequested) {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Return to previous page")
        .help("Return to previous page")
    }

#if os(iOS)
    private var searchToolbarButton: some View {
        Button(action: searchPageButtonTapped) {
            Image(systemName: pageMode == .search ? "xmark.circle" : "magnifyingglass")
        }
        .accessibilityLabel(pageMode == .search ? "Return to previous page" : "Search tasks and history")
        .help(pageMode == .search ? "Return to previous page" : "Search tasks and history")
    }
#endif

#if os(iOS)
    private var historyActionsMenu: some View {
        Menu {
            Button("Previous Day", action: navigateToPreviousHistoryDayButtonTapped)
                .disabled(previousHistoryDay == nil)

            Button("Next Day", action: navigateToNextHistoryDayButtonTapped)
                .disabled(nextHistoryDay == nil)

            Button("Export All Sessions", action: exportAllSessionsToolbarButtonTapped)
                .disabled(completedHistorySessionIDs.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("History actions")
    }
#endif

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
    private var navigationTitle: String {
        switch pageMode {
        case .history:
            return SessionHistoryBrowserSupport.dayLabel(selectedHistoryDay)
        case .search:
            return "Search"
        case .live:
            return ""
        }
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

#if !os(macOS)
    private func searchPageButtonTapped() {
        if pageMode == .search {
            handleSearchExitRequested()
            return
        }

        enterSearchModeIfNeeded()
    }
#endif

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
        pageMode = .history
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
    }

    private func exitHistoryMode() {
        pageMode = .live
    }

    private func enterSearchModeIfNeeded() {
        guard pageMode != .search else { return }
        searchReturnMode = pageMode
        pageMode = .search
    }

    private func handleSearchExitRequested() {
        if usesToolbarUnifiedSearchField {
            searchModel.resetSearch()
        }
        exitSearchMode()
    }

    private func exitSearchMode() {
        let destination = searchReturnMode == .search ? SessionPageMode.live : searchReturnMode
        pageMode = destination
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

    private func configureSearchModel() {
        searchModel.update(
            sessions: store.settings.sessions,
            excludingActiveSessionID: store.activeSession?.id,
            onGoToDayRequested: navigateToHistoryDayFromSearch(_:),
            onGoToSessionRequested: navigateToHistorySessionFromSearch(_:),
            onExitRequested: handleSearchExitRequested
        )
    }

    private func focusSearchFieldSoon() {
        DispatchQueue.main.async {
            isSearchFieldFocused = true
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
        pageMode = .history
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
        searchModel.resetSearch()
    }

    private func navigateToHistorySessionFromSearch(_ session: FocusSessionRecord) {
        pageMode = .history
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: session.startedAt)
        selectedHistorySessionID = session.id
        searchModel.resetSearch()
    }

    private var usesToolbarUnifiedSearchField: Bool {
#if os(macOS)
        true
#else
        !isPhone
#endif
    }

#if os(iOS)
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
#endif
}

private extension View {
    @ViewBuilder
    func applyUnifiedToolbarSearch(
        isEnabled: Bool,
        query: Binding<String>,
        isSearchFieldFocused: FocusState<Bool>.Binding
    ) -> some View {
        if isEnabled {
            self
                .searchable(
                    text: query,
                    placement: .toolbar,
                    prompt: "Search tasks and history"
                )
                .searchFocused(isSearchFieldFocused)
        } else {
            self
        }
    }
}
