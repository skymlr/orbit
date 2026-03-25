#if os(iOS)
import ComposableArchitecture
import SwiftUI

struct OrbitPhoneShellView: View {
    private enum RootTab: String, CaseIterable, Identifiable {
        case session
        case history
        case settings

        var id: Self { self }

        var title: String {
            switch self {
            case .session:
                return "Session"
            case .history:
                return "History"
            case .settings:
                return "Settings"
            }
        }

        var symbolName: String {
            switch self {
            case .session:
                return "checklist"
            case .history:
                return "clock.arrow.circlepath"
            case .settings:
                return "gearshape"
            }
        }
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var selectedTab: RootTab = .session

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            phoneBackground
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                sessionRoot
                    .tabItem {
                        Label(RootTab.session.title, systemImage: RootTab.session.symbolName)
                    }
                    .tag(RootTab.session)

                historyRoot
                    .tabItem {
                        Label(RootTab.history.title, systemImage: RootTab.history.symbolName)
                    }
                    .tag(RootTab.history)

                settingsRoot
                    .tabItem {
                        Label(RootTab.settings.title, systemImage: RootTab.settings.symbolName)
                    }
                    .tag(RootTab.settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tint(OrbitTheme.Palette.orbitLine)

            quickCaptureButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            toastInset
        }
        .fullScreenCover(isPresented: capturePresentationBinding) {
            quickCapture
        }
        .onChange(of: store.presentation.preferencesPresentationRequest) { oldValue, newValue in
            if newValue != oldValue {
                preferencesPresentationRequested()
            }
        }
        .onChange(of: store.presentation.workspacePresentationRequest) { oldValue, newValue in
            if newValue != oldValue {
                selectedTab = .session
            }
        }
        .animation(.easeInOut(duration: 0.24), value: store.toast?.id)
    }

    private var sessionRoot: some View {
        phoneNavigationStack {
            SessionLiveView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background {
                    OrbitSpaceBackground(
                        style: store.appearance.background,
                        showsOrbitalLayer: store.appearance.showsOrbitalLayer
                    )
                }
        }
    }

    private var historyRoot: some View {
        phoneNavigationStack {
            OrbitPhoneHistoryRootView(
                store: store,
                onBackToSession: backToSessionButtonTapped
            )
        }
    }

    private var settingsRoot: some View {
        phoneNavigationStack {
            PreferencesView(store: store)
        }
    }

    private var phoneBackground: some View {
        OrbitSpaceBackground(
            style: store.appearance.background,
            showsOrbitalLayer: store.appearance.showsOrbitalLayer
        )
    }

    private func phoneNavigationStack<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background {
            phoneBackground
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var quickCaptureButton: some View {
        Button(action: quickCaptureButtonTapped) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 58, height: 58)
        }
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        .padding(.trailing, 18)
        .padding(.bottom, 50)
        .accessibilityLabel("Quick Capture")
        .accessibilityHint("Capture a task from anywhere in the app")
    }

    @ViewBuilder
    private var toastInset: some View {
        if let toast = store.toast {
            OrbitToastView(
                toast: toast,
                onDismiss: dismissToastButtonTapped
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.orbitToastNotification.combined(with: .opacity))
        }
    }

    private var capturePresentationBinding: Binding<Bool> {
        Binding(
            get: { store.presentation.isCapturePresented },
            set: { isPresented in
                if !isPresented {
                    store.send(.captureWindowClosed)
                }
            }
        )
    }

    @ViewBuilder
    private var quickCapture: some View {
        NavigationStack {
            QuickCaptureView(store: store)
                .orbitAppearance(store.appearance)
                .preferredColorScheme(.dark)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func quickCaptureButtonTapped() {
        if store.activeSession == nil {
            store.send(.captureTapped)
        } else {
            store.send(.sessionAddTaskTapped)
        }
    }

    private func backToSessionButtonTapped() {
        selectedTab = .session
    }

    private func dismissToastButtonTapped() {
        store.send(.toastDismissTapped)
    }

    private func preferencesPresentationRequested() {
        selectedTab = .settings
        store.send(.preferencesWindowClosed)
    }
}

private struct OrbitPhoneHistoryRootView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    let onBackToSession: () -> Void

    @State private var selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: Date())
    @State private var selectedHistorySessionID: UUID?
    @State private var isHistoryCalendarPresented = false
    @State private var isExportAllConfirmationPresented = false
    @StateObject private var historySearchModel = HistorySearchPanelModel()

    var body: some View {
        historyContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background {
                OrbitSpaceBackground(
                    style: store.appearance.background,
                    showsOrbitalLayer: store.appearance.showsOrbitalLayer
                )
            }
            .navigationTitle("History")
            .orbitInlineNavigationTitleDisplayMode()
            .searchable(text: $historySearchModel.query, placement: .toolbar, prompt: "Search history")
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
                historyTask()
            }
            .onChange(of: historyDayGroups) { _, _ in
                historyDayGroupsChanged()
            }
            .onChange(of: store.appearance) { _, _ in
                refreshHistorySearchModelIfNeeded()
            }
    }

    @ViewBuilder
    private var historyContent: some View {
        if isShowingInlineHistorySearchResults {
            HistorySearchView(model: historySearchModel)
        } else {
            SessionHistoryView(
                store: store,
                historyDayGroups: historyDayGroups,
                selectedHistoryDay: selectedHistoryDay,
                selectedHistorySessionID: selectedHistorySessionID,
                onExitHistoryMode: onBackToSession,
                onSelectHistorySession: selectHistorySession(_:),
                onExportSession: exportSessionButtonTapped(sessionID:)
            )
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

    private var trimmedHistorySearchQuery: String {
        historySearchModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isShowingInlineHistorySearchResults: Bool {
        !trimmedHistorySearchQuery.isEmpty
    }

    private func historyTask() {
        reconcileHistorySelection()
        refreshHistorySearchModelIfNeeded()
    }

    private func historyDayGroupsChanged() {
        reconcileHistorySelection()
        refreshHistorySearchModelIfNeeded()
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

    private func refreshHistorySearchModelIfNeeded() {
        historySearchModel.sessions = store.settings.sessions
        historySearchModel.excludingActiveSessionID = store.activeSession?.id
        historySearchModel.appearance = store.appearance
        historySearchModel.onGoToDayRequested = navigateToHistoryDayFromSearch(_:)
        historySearchModel.onGoToSessionRequested = navigateToHistorySessionFromSearch(_:)
        historySearchModel.onCloseRequested = clearHistorySearch
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
        clearHistorySearch()
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

    private func navigateToHistoryDayFromSearch(_ day: Date) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: day)
        selectedHistorySessionID = SessionHistoryBrowserSupport.defaultSessionID(
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
        clearHistorySearch()
    }

    private func navigateToHistorySessionFromSearch(_ session: FocusSessionRecord) {
        selectedHistoryDay = SessionHistoryBrowserSupport.normalizedDay(for: session.startedAt)
        selectedHistorySessionID = session.id
        clearHistorySearch()
    }

    private func clearHistorySearch() {
        historySearchModel.resetSearch()
    }
}
#endif
