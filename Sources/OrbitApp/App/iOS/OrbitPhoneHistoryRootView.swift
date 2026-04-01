#if os(iOS)
import ComposableArchitecture
import SwiftUI

struct OrbitPhoneHistoryRootView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Binding var selectedHistoryDay: Date
    @Binding var selectedHistorySessionID: UUID?
    let onBackToSession: () -> Void

    @State private var isHistoryCalendarPresented = false
    @State private var isExportAllConfirmationPresented = false

    var body: some View {
        SessionHistoryView(
            store: store,
            historyDayGroups: historyDayGroups,
            selectedHistoryDay: selectedHistoryDay,
            selectedHistorySessionID: selectedHistorySessionID,
            onExitHistoryMode: onBackToSession,
            onSelectHistorySession: selectHistorySession(_:),
            onExportSession: exportSessionButtonTapped(sessionID:)
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                OrbitSpaceBackground(
                    style: store.appearance.background,
                    showsOrbitalLayer: store.appearance.showsOrbitalLayer
                )
            }
            .navigationTitle("History")
            .orbitInlineNavigationTitleDisplayMode()
            .toolbar {
                historyToolbarContent
            }
            .sheet(isPresented: $isHistoryCalendarPresented) {
                historyCalendarSheet
            }
            .confirmationDialog(
                "Export All Sessions?",
                isPresented: $isExportAllConfirmationPresented
            ) {
                Button("Export \(completedHistorySessionIDs.count) Session\(completedHistorySessionIDs.count == 1 ? "" : "s")") {
                    exportAllSessionsConfirmationAccepted()
                }
                .disabled(completedHistorySessionIDs.isEmpty)

                Button("Cancel", role: .cancel) {
                    isExportAllConfirmationPresented = false
                }
            } message: {
                Text("Export markdown files for every completed session currently saved in history.")
            }
            .task(id: store.activeSession?.id) {
                reconcileHistorySelection()
            }
            .onChange(of: historyDayGroups) { _, _ in
                reconcileHistorySelection()
            }
    }

    @ToolbarContentBuilder
    private var historyToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: openHistoryCalendarButtonTapped) {
                Image(systemName: "calendar")
            }
            .disabled(historyDayGroups.isEmpty)
            .accessibilityLabel("Browse history by day")
        }

        ToolbarItem(placement: .topBarTrailing) {
            historyActionsMenu
        }
    }

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

    @ViewBuilder
    private var historyCalendarSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pick a day to jump straight into Orbit's archived session timeline.")
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)

                HistoryCalendarPickerView(
                    availableDays: Set(historyDayGroups.map(\.day)),
                    selectedDay: selectedHistoryDay,
                    onSelectDay: selectHistoryCalendarDay(_:)
                )

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(OrbitSpaceBackground())
            .navigationTitle("Jump To Day")
            .orbitInlineNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismissHistoryCalendarButtonTapped()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

    private func reconcileHistorySelection() {
        let normalizedSelectedDay = SessionHistoryBrowserSupport.normalizedDay(for: selectedHistoryDay)
        let selectedDaySessions = SessionHistoryBrowserSupport.sessions(
            on: normalizedSelectedDay,
            from: historyDayGroups
        )

        if selectedDaySessions.isEmpty {
            selectedHistoryDay = SessionHistoryBrowserSupport.defaultSelectedDay(
                from: historyDayGroups,
                fallback: normalizedSelectedDay
            )
        } else {
            selectedHistoryDay = normalizedSelectedDay
        }

        selectedHistorySessionID = SessionHistoryBrowserSupport.resolveSelectedSession(
            id: selectedHistorySessionID,
            on: selectedHistoryDay,
            groups: historyDayGroups
        )?.id
    }

    private func selectHistorySession(_ sessionID: UUID) {
        selectedHistorySessionID = sessionID
    }

    private func openHistoryCalendarButtonTapped() {
        isHistoryCalendarPresented = true
    }

    private func dismissHistoryCalendarButtonTapped() {
        isHistoryCalendarPresented = false
    }

    private func selectHistoryCalendarDay(_ day: Date) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
        isHistoryCalendarPresented = false
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

}
#endif
