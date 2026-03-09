import AppKit
import ComposableArchitecture
import SwiftUI

struct WorkspaceView: View {
    private enum SectionWidth {
        static let section: CGFloat = 700
    }

    private enum WorkspaceSection: String, CaseIterable, Identifiable {
        case session = "Session"
        case categories = "Categories"
        case hotkeys = "Hotkeys"
        case about = "About"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .session:
                return "play.circle"
            case .categories:
                return "folder"
            case .hotkeys:
                return "keyboard"
            case .about:
                return "info.circle"
            }
        }
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
        .animation(.easeInOut(duration: 0.24), value: store.toast?.id)
    }

    @ViewBuilder
    private func selectedSectionContent(for section: WorkspaceSection) -> some View {
        switch section {
        case .session:
            SessionPageView(store: store)
                .id(section)
                .transition(.orbitMicro)
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

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            aboutSummaryCard
            thirdPartyCreditsCard
        }
        .frame(maxWidth: sectionMaxWidth(for: .about))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var aboutSummaryCard: some View {
        aboutPanel {
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

                Divider()

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
    }

    private var thirdPartyCreditsCard: some View {
        aboutPanel {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Third-Party Credits")
                        .font(.title3.weight(.semibold))
                    Text("\(ThirdPartyCredits.all.count) packages in Orbit's current SwiftPM dependency graph.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Each package links to its project page and the pinned license file for the revision currently resolved in this app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(ThirdPartyCredits.all) { credit in
                        ThirdPartyCreditCard(credit: credit)
                    }
                }
            }
        }
    }

    private var historicalSessions: [FocusSessionRecord] {
        store.settings.sessions.filter { session in
            session.endedAt != nil && session.id != store.activeSession?.id
        }
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

    @ViewBuilder
    private func aboutPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        sectionCard {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
        )
    }
}

private struct ThirdPartyCreditCard: View {
    let credit: ThirdPartyCredit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(credit.name)
                        .font(.headline.weight(.semibold))

                    Text(credit.packageID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    CreditMetadataChip(title: "v\(credit.version)", usesMonospacedDigits: true)
                    CreditMetadataChip(title: credit.licenseName)
                }
            }

            HStack(spacing: 8) {
                Link(destination: credit.repositoryURL) {
                    Label("Project", systemImage: "link")
                }
                .buttonStyle(.orbitQuiet)

                Link(destination: credit.licenseURL) {
                    Label("License", systemImage: "doc.text")
                }
                .buttonStyle(.orbitQuiet)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
        )
    }
}

private struct CreditMetadataChip: View {
    let title: String
    var usesMonospacedDigits = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(usesMonospacedDigits ? .caption.monospacedDigit().weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var textColor: Color {
        colorScheme == .dark
            ? .primary
            : OrbitTheme.Palette.lightTextSecondary
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.glassFillSubtle
            : OrbitTheme.Palette.lightPanelSoft
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.glassBorderStrong.opacity(0.88)
            : OrbitTheme.Palette.lightStrokeSoft.opacity(0.42)
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
                        .fill(Color(orbitHex: colorHex))
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
