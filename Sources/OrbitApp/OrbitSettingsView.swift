import AppKit
import ComposableArchitecture
import SwiftUI

struct OrbitSettingsView: View {
    private enum SectionWidth {
        static let section: CGFloat = 700
    }

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case sessions = "Sessions"
        case categories = "Categories"
        case hotkeys = "Hotkeys"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .sessions:
                return "clock.arrow.circlepath"
            case .categories:
                return "folder"
            case .hotkeys:
                return "keyboard"
            }
        }
    }

    private struct SessionDayGroup: Identifiable {
        let day: Date
        let sessions: [FocusSessionRecord]

        var id: Date { day }
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSection: SettingsSection = .sessions
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = FocusDefaults.defaultCategoryColorHex

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            OrbitSpaceBackground()
        }
    }

    @ViewBuilder
    private func selectedSectionContent(for section: SettingsSection) -> some View {
        switch section {
        case .sessions:
            sessionsSection
        case .categories:
            categoriesSection
        case .hotkeys:
            hotkeysSection
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.rawValue, systemImage: section.iconName)
                    .font(.body.weight(.semibold))
                    .tag(section)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSection = section
                    }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                selectedSectionContent(for: selectedSection)

                if let message = store.settings.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(selectedSection.rawValue)
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

    private var sessionsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                if let activeSession = store.activeSession {
                    ActiveSessionHero(
                        session: activeSession,
                        categoryColorHex: categoryColorHex(for: activeSession.categoryID),
                        onOpenSession: {
                            openActiveSessionButtonTapped()
                        }
                    )
                }

                if sessionGroups.isEmpty {
                    Text("No completed sessions yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(sessionGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dayHeader(group.day))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.cyan)

                        ForEach(group.sessions) { session in
                            SessionRow(
                                session: session,
                                categoryColorHex: categoryColorHex(for: session.categoryID),
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
        .frame(maxWidth: sectionMaxWidth(for: .sessions))
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

    private func openActiveSessionButtonTapped() {
        store.send(.openSessionTapped)
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "session-window")

        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Orbit Session" }) else {
                return
            }
            window.orderFrontRegardless()
            window.makeKey()
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

    private func categoryColorHex(for categoryID: UUID) -> String {
        store.settings.categories.first(where: { $0.id == categoryID })?.colorHex
            ?? FocusDefaults.defaultCategoryColorHex
    }

    private func sectionMaxWidth(for section: SettingsSection) -> CGFloat {
        SectionWidth.section
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
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
                    .disabled(category.id == FocusDefaults.focusCategoryID)

                Button("Save") {
                    onRename(name, selectedColorHex)
                }
                .buttonStyle(.orbitSecondary)

                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.orbitDestructive)
                .disabled(category.id == FocusDefaults.focusCategoryID)
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
                .help(colorHex)
                .accessibilityLabel("Category color \(colorHex)")
            }
        }
    }
}

private struct SessionRow: View {
    let session: FocusSessionRecord
    let categoryColorHex: String
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
                Text(session.categoryName.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(categoryHex: categoryColorHex).opacity(0.25))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(categoryHex: categoryColorHex).opacity(0.95), lineWidth: 1)
                    )

                Text("\(session.notes.count) \(session.notes.count == 1 ? "note" : "notes")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Started \(session.startedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
}

private struct ActiveSessionHero: View {
    let session: FocusSessionRecord
    let categoryColorHex: String
    let onOpenSession: () -> Void

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

                Button("Open Session") {
                    onOpenSession()
                }
                .buttonStyle(.orbitPrimary)
            }

            HStack(spacing: 8) {
                Text(session.categoryName.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(categoryHex: categoryColorHex).opacity(0.25))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(categoryHex: categoryColorHex).opacity(0.95), lineWidth: 1)
                    )

                Text("\(session.notes.count) \(session.notes.count == 1 ? "note" : "notes")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Started \(session.startedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Elapsed \(session.startedAt, style: .timer)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(categoryHex: categoryColorHex).opacity(0.60), lineWidth: 1)
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
