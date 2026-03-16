import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI

struct SessionPageView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    @State private var isHistoryMode = false
    @State private var selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: Date())
    @State private var selectedHistorySessionID: UUID?
    @State private var isHistoryCalendarPresented = false
    @State private var isExportAllConfirmationPresented = false
    @State private var isHistorySearchPresented = false
    @State private var historySearchPanelController = HistorySearchPanelController()

    var body: some View {
        Group {
            if isHistoryMode {
                SessionHistoryView(
                    store: store,
                    historyDayGroups: historyDayGroups,
                    selectedHistoryDay: selectedHistoryDay,
                    selectedHistorySessionID: selectedHistorySessionID,
                    onExitHistoryMode: exitHistoryMode,
                    onSelectHistorySession: selectHistorySession(_:),
                    onExportSession: exportSessionButtonTapped(sessionID:)
                )
            } else {
                SessionLiveView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(18)
        .frame(minWidth: 880, minHeight: 640)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.send(.sessionAddTaskTapped)
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .help("Capture Task \(HotkeyHintFormatter.hint(from: store.hotkeys.captureShortcut))")

                Button {
                    isHistoryCalendarPresented = true
                } label: {
                    Image(systemName: "calendar")
                }
                .help("Browse session history by day")
                .popover(isPresented: $isHistoryCalendarPresented, arrowEdge: .bottom) {
                    historyCalendarPopover
                }

                if isHistoryMode {
                    Button {
                        navigateHistoryDay(.previous)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(previousHistoryDay == nil)
                    .help("Older session day")

                    Button {
                        navigateHistoryDay(.next)
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
                    .help("Open floating history search")

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
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
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

    private func selectHistorySession(_ sessionID: UUID) {
        selectedHistorySessionID = sessionID
    }

    private func exportAllSessionsToolbarButtonTapped() {
        guard !completedHistorySessionIDs.isEmpty else { return }
        isExportAllConfirmationPresented = true
    }

    private func exportAllSessionsConfirmationAccepted() {
        guard !completedHistorySessionIDs.isEmpty else { return }
        chooseExportDirectory { url in
            store.send(.settingsExportAllTapped(url))
        }
    }

    private func exportSessionButtonTapped(sessionID: UUID) {
        chooseExportDirectory { url in
            store.send(.settingsExportSessionTapped(sessionID, url))
        }
    }

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

    private func enterHistoryMode(on day: Date) {
        isHistoryMode = true
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
    }

    private func exitHistoryMode() {
        dismissHistorySearchPanel()
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
        isHistorySearchPresented = true
        historySearchPanelController.present(
            configuration: historySearchPanelConfiguration(),
            resetSearch: shouldResetSearch
        )
    }

    private func dismissHistorySearchPanel() {
        guard isHistorySearchPresented else { return }
        isHistorySearchPresented = false
        historySearchPanelController.dismiss()
    }

    private func refreshHistorySearchPanelIfNeeded() {
        guard isHistorySearchPresented else { return }
        historySearchPanelController.refresh(configuration: historySearchPanelConfiguration())
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

    private func navigateToHistoryDayFromSearch(_ day: Date) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
    }

    private func navigateToHistorySessionFromSearch(day: Date, sessionID: UUID) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = sessionID
    }
}
