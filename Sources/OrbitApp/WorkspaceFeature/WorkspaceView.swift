import AppKit
import ComposableArchitecture
import SwiftUI

struct WorkspaceView: View {
    private enum SectionWidth {
        static let section: CGFloat = 700
    }

    private enum WorkspaceSection: String, CaseIterable, Identifiable {
        case session = "Session"
        case history = "History"
        case categories = "Categories"
        case hotkeys = "Hotkeys"
        case about = "About"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .session:
                return "play.circle"
            case .history:
                return "clock.arrow.circlepath"
            case .categories:
                return "folder"
            case .hotkeys:
                return "keyboard"
            case .about:
                return "info.circle"
            }
        }
    }

    private struct SessionDayGroup: Identifiable {
        let day: Date
        let sessions: [FocusSessionRecord]

        var id: Date { day }
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var selectedSection: WorkspaceSection = .session
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = FocusDefaults.defaultCategoryColorHex

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            store.send(.settingsRefreshTapped)
        }
        .onChange(of: store.workspaceWindowFocusRequest) { _, _ in
            resetWorkspaceDestination()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            OrbitSpaceBackground()
        }
        .overlay(alignment: .topTrailing) {
            if let toast = store.toast {
                OrbitToastView(
                    toast: toast,
                    onDismiss: {
                        store.send(.toastDismissTapped)
                    }
                )
                .padding(.top, 14)
                .padding(.trailing, 18)
                .transition(.orbitToastNotification)
            }
        }
        .overlay {
            if let transitionState = store.sessionWindowTransitionState {
                SessionWindowTransitionOverlay(
                    transitionState: transitionState,
                    onRetry: {
                        store.send(.sessionWindowTransitionRetryTapped)
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: store.toast?.id)
        .animation(.easeInOut(duration: 0.18), value: store.sessionWindowTransitionState)
    }

    @ViewBuilder
    private func selectedSectionContent(for section: WorkspaceSection) -> some View {
        switch section {
        case .session:
            SessionPageView(store: store)
                .id(section)
                .transition(.orbitMicro)
        case .history:
            historySection
        case .categories:
            categoriesSection
        case .hotkeys:
            hotkeysSection
        case .about:
            aboutSection
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(WorkspaceSection.allCases) { section in
                Label(section.rawValue, systemImage: section.iconName)
                    .font(.body.weight(.semibold))
                    .tag(section)
                    .contentShape(Rectangle())
                    .orbitPointerCursor()
                    .onTapGesture {
                        selectedSection = section
                    }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
    }

    private var detailContent: some View {
        Group {
            if selectedSection == .session {
                selectedSectionContent(for: selectedSection)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack(alignment: .topLeading) {
                            selectedSectionContent(for: selectedSection)
                                .id(selectedSection)
                                .transition(.orbitMicro)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(selectedSection.rawValue)
        .animation(.easeInOut(duration: 0.18), value: selectedSection)
    }

    private var hotkeysSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Shortcut (Open/Start)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("ctrl+option+cmd+k", text: $store.settings.startShortcut)
                    .textFieldStyle(.roundedBorder)

                Text("Quick Capture Shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("ctrl+option+cmd+j", text: $store.settings.captureShortcut)
                    .textFieldStyle(.roundedBorder)

                Divider()
                    .padding(.vertical, 2)

                Text("Quick Capture: Next Priority")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("cmd+.", text: $store.settings.captureNextPriorityShortcut)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Reset Hotkeys") {
                        store.send(.settingsResetHotkeysTapped)
                    }
                    .buttonStyle(.orbitSecondary)

                    Spacer()
                    Button("Save Hotkeys") {
                        store.send(.settingsSaveHotkeysTapped)
                    }
                    .buttonStyle(.orbitPrimary)
                }
            }
        }
        .frame(maxWidth: sectionMaxWidth(for: .hotkeys))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var categoriesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Add category", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            addCategoryButtonTapped()
                        }
                        .buttonStyle(.orbitSecondary)
                    }

                    CategoryColorPalettePicker(selectedHex: $newCategoryColorHex)
                }

                ForEach(store.settings.categories) { category in
                    CategoryRow(
                        category: category,
                        onRename: { newName, colorHex in
                            store.send(.settingsRenameCategoryTapped(category.id, newName, colorHex))
                        },
                        onDelete: {
                            store.send(.settingsDeleteCategoryTapped(category.id))
                        }
                    )
                }
            }
        }
        .frame(maxWidth: sectionMaxWidth(for: .categories))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var historySection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                if let activeSession = store.activeSession {
                    ActiveSessionHero(
                        session: activeSession,
                        endSessionDraft: store.endSessionDraft,
                        onOpenSession: {
                            openSessionSectionButtonTapped()
                        },
                        onEndSessionTapped: {
                            store.send(.endSessionTapped)
                        },
                        onEndSessionConfirm: { name in
                            store.send(.endSessionConfirmTapped(name: name))
                        },
                        onEndSessionCancel: {
                            store.send(.endSessionCancelTapped)
                        }
                    )
                    .transition(.orbitMicro)
                }

                if sessionGroups.isEmpty {
                    Text("No completed sessions yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.orbitMicro)
                }

                ForEach(sessionGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dayHeader(group.day))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.cyan)

                        ForEach(group.sessions) { session in
                            SessionRow(
                                session: session,
                                onRename: { newName in
                                    store.send(.settingsRenameSessionTapped(session.id, newName))
                                },
                                onDelete: {
                                    store.send(.settingsDeleteSessionTapped(session.id))
                                },
                                onExport: {
                                    exportSessionButtonTapped(sessionID: session.id)
                                }
                            )
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Export All Sessions") {
                        exportAllSessionsButtonTapped()
                    }
                    .buttonStyle(.orbitSecondary)
                    .disabled(historicalSessions.isEmpty)
                }
            }
        }
        .frame(maxWidth: sectionMaxWidth(for: .history))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var aboutSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Orbit: A Focus Manager")
                        .font(.title2.weight(.bold))
                    Text("Version \(appVersionString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Built for focused work on macOS.")
                        .font(.body)

                    Text("Features")
                        .font(.headline.weight(.semibold))
                    Text("• Menu bar-first session management")
                    Text("• Quick capture with markdown tasks")
                    Text("• Task categories, filters, priorities, and session exports")
                    Text("• Local-first SQLite persistence")
                }
                .font(.subheadline)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current shortcuts")
                        .font(.headline.weight(.semibold))
                    Text("Open/Start Session: \(store.settings.startShortcut)")
                    Text("Quick Capture: \(store.settings.captureShortcut)")
                    Text("Capture Next Priority: \(store.settings.captureNextPriorityShortcut)")
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: sectionMaxWidth(for: .about))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var historicalSessions: [FocusSessionRecord] {
        store.settings.sessions.filter { session in
            session.endedAt != nil && session.id != store.activeSession?.id
        }
    }

    private var sessionGroups: [SessionDayGroup] {
        let grouped = Dictionary(grouping: historicalSessions) { session in
            Calendar.current.startOfDay(for: session.startedAt)
        }

        return grouped.keys
            .sorted(by: >)
            .map { day in
                SessionDayGroup(
                    day: day,
                    sessions: grouped[day, default: []].sorted(by: { $0.startedAt > $1.startedAt })
                )
            }
    }

    private func dayHeader(_ day: Date) -> String {
        let formatted = day.formatted(date: .abbreviated, time: .omitted)
        if Calendar.current.isDateInToday(day) {
            return "Today • \(formatted)"
        }
        if Calendar.current.isDateInYesterday(day) {
            return "Yesterday • \(formatted)"
        }
        return formatted
    }

    private func exportAllSessionsButtonTapped() {
        chooseExportDirectory { url in
            store.send(.settingsExportAllTapped(url))
        }
    }

    private func addCategoryButtonTapped() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        store.send(.settingsAddCategoryTapped(trimmedName, newCategoryColorHex))
        newCategoryName = ""
        newCategoryColorHex = FocusDefaults.defaultCategoryColorHex
    }

    private func exportSessionButtonTapped(sessionID: UUID) {
        chooseExportDirectory { url in
            store.send(.settingsExportSessionTapped(sessionID, url))
        }
    }

    private func openSessionSectionButtonTapped() {
        selectedSection = .session
        columnVisibility = .detailOnly
    }

    private func resetWorkspaceDestination() {
        selectedSection = .session
        columnVisibility = .detailOnly
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

    private func sectionMaxWidth(for section: WorkspaceSection) -> CGFloat {
        SectionWidth.section
    }

    private var appVersionString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case let (short?, _) where !short.isEmpty:
            return short
        case let (_, build?) where !build.isEmpty:
            return build
        default:
            return "Development"
        }
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "OrbitApp"
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
    }
}

private struct SessionWindowTransitionOverlay: View {
    let transitionState: AppFeature.State.SessionWindowTransitionState
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.40)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                switch transitionState {
                case let .inProgress(from, to):
                    ProgressView()
                        .controlSize(.large)
                    Text("Ending \(from.title) Session and starting \(to.title) Session...")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)

                case let .failed(from, to, message):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Could not start \(to.title) Session")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .frame(maxWidth: 360)
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.orbitPrimary)
                    .help("Retry ending \(from.title) Session and starting \(to.title) Session")
                }
            }
            .padding(20)
            .frame(maxWidth: 460)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(24)
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .contain)
    }
}

private struct CategoryRow: View {
    let category: SessionCategoryRecord
    let onRename: (String, String) -> Void
    let onDelete: () -> Void

    @State private var name = ""
    @State private var selectedColorHex = FocusDefaults.defaultCategoryColorHex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Category", text: $name)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    onRename(name, selectedColorHex)
                }
                .buttonStyle(.orbitSecondary)

                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.orbitDestructive)
            }

            CategoryColorPalettePicker(selectedHex: $selectedColorHex)
        }
        .task(id: category.id) {
            name = category.name
            let normalized = FocusDefaults.normalizedCategoryColorHex(category.colorHex)
            if FocusDefaults.categoryColorOptions.contains(normalized) {
                selectedColorHex = normalized
            } else {
                selectedColorHex = FocusDefaults.defaultCategoryColorHex
            }
        }
    }
}

private struct CategoryColorPalettePicker: View {
    @Binding var selectedHex: String

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 10),
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(FocusDefaults.categoryColorOptions, id: \.self) { colorHex in
                let isSelected = selectedHex == colorHex

                Button {
                    selectedHex = colorHex
                } label: {
                    Circle()
                        .fill(Color(categoryHex: colorHex))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isSelected ? 0.95 : 0.45), lineWidth: isSelected ? 2 : 1)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.22), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .orbitInteractiveControl(
                    scale: 1.12,
                    lift: -1.0,
                    shadowColor: Color.white.opacity(0.18),
                    shadowRadius: 4
                )
                .help(colorHex)
                .accessibilityLabel("Category color \(colorHex)")
            }
        }
    }
}

private struct SessionRow: View {
    let session: FocusSessionRecord
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    @State private var isRenaming = false
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if isRenaming {
                    TextField("Session name", text: $name)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(session.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                Button(isRenaming ? "Save" : "Rename") {
                    renameButtonTapped()
                }
                .buttonStyle(.orbitSecondary)
                .disabled(isRenaming && trimmedName.isEmpty)

                Button("Export") {
                    onExport()
                }
                .buttonStyle(.orbitSecondary)
            }

            HStack(spacing: 8) {
                Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Started \(session.startedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let endedAt = session.endedAt {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Ended \(endedAt, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Elapsed \(elapsedText(startedAt: session.startedAt, endedAt: endedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.orbitDestructive)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
        .task(id: session.id) {
            name = session.name
            isRenaming = false
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renameButtonTapped() {
        if isRenaming {
            onRename(trimmedName)
            isRenaming = false
        } else {
            isRenaming = true
        }
    }

    private func elapsedText(startedAt: Date, endedAt: Date) -> String {
        let seconds = max(endedAt.timeIntervalSince(startedAt), 0)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.dropLeading]
        return formatter.string(from: seconds) ?? "0m"
    }
}

private struct ActiveSessionHero: View {
    let session: FocusSessionRecord
    let endSessionDraft: AppFeature.State.EndSessionDraft?
    let onOpenSession: () -> Void
    let onEndSessionTapped: () -> Void
    let onEndSessionConfirm: (String) -> Void
    let onEndSessionCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Session")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(session.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                }

                Spacer()

                Button("Go to Session") {
                    onOpenSession()
                }
                .buttonStyle(.orbitPrimary)
            }

            HStack(spacing: 8) {
                Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Started \(session.startedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Elapsed \(session.startedAt, style: .timer)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Ends at \(FocusDefaults.nextSessionBoundary(after: session.startedAt), style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("End Session", role: .destructive) {
                    onEndSessionTapped()
                }
                .buttonStyle(.orbitDestructive)
                .popover(
                    isPresented: Binding(
                        get: { endSessionDraft != nil },
                        set: { isPresented in
                            if !isPresented {
                                onEndSessionCancel()
                            }
                        }
                    ),
                    arrowEdge: .bottom
                ) {
                    if let draft = endSessionDraft {
                        EndSessionPromptView(
                            draft: draft,
                            onConfirm: onEndSessionConfirm,
                            onCancel: onEndSessionCancel
                        )
                    }
                }
                .transition(.orbitMicro)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.cyan.opacity(0.60), lineWidth: 1)
                )
        )
    }
}

private extension Color {
    init(categoryHex: String) {
        let normalized = FocusDefaults.normalizedCategoryColorHex(categoryHex)
        let hex = String(normalized.dropFirst())
        let value = UInt64(hex, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
