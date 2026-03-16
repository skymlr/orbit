import ComposableArchitecture
import SwiftUI

struct PreferencesView: View {
    private enum PreferencesSidebarGroup: String, CaseIterable, Identifiable {
        case workspace = "Workspace"
        case orbit = "Orbit"

        var id: Self { self }
    }

    private enum PreferencesSection: String, CaseIterable, Identifiable {
        case categories = "Categories"
        case hotkeys = "Hotkeys"
        case about = "About"
        case credits = "Credits"

        var id: Self { self }

        var title: String { rawValue }

        var subtitle: String {
            switch self {
            case .categories:
                return "Organize quick capture and session notes with reusable category labels."
            case .hotkeys:
                return "Configure the global shortcuts Orbit registers with macOS."
            case .about:
                return "Versioning, identifiers, and the product-level details for this build."
            case .credits:
                return "Browse the open-source packages bundled into the current Orbit build."
            }
        }

        var symbolName: String {
            switch self {
            case .categories:
                return "square.grid.2x2"
            case .hotkeys:
                return "command"
            case .about:
                return "info.circle"
            case .credits:
                return "shippingbox"
            }
        }

        var group: PreferencesSidebarGroup {
            switch self {
            case .categories, .hotkeys:
                return .workspace
            case .about, .credits:
                return .orbit
            }
        }
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: PreferencesSection? = .categories
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = FocusDefaults.defaultCategoryColorHex

    private var activeSection: PreferencesSection {
        selectedSection ?? .categories
    }

    var body: some View {
        splitView
            .task {
                store.send(.settingsRefreshTapped)
            }
            .background {
                preferencesBackground
            }
            .onExitCommand {
                dismiss()
            }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detailContent
        }
    }

    @ViewBuilder
    private var preferencesBackground: some View {
        if #available(macOS 26.0, *) {
            OrbitSpaceBackground()
                .backgroundExtensionEffect()
        } else {
            OrbitSpaceBackground()
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(PreferencesSidebarGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(sections(in: group)) { section in
                        sidebarRow(for: section)
                            .tag(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar(removing: .sidebarToggle)
    }

    private var detailContent: some View {
        Group {
            switch activeSection {
            case .categories:
                categoriesPage
            case .hotkeys:
                hotkeysPage
            case .about:
                aboutPage
            case .credits:
                creditsPage
            }
        }
        .id(activeSection)
        .animation(.easeInOut(duration: 0.18), value: activeSection)
    }

    private var categoriesPage: some View {
        detailPage(for: .categories) {
            preferencesSectionCard(
                title: "Category Library"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        TextField("Add category", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            addCategoryButtonTapped()
                        }
                        .buttonStyle(.orbitSecondary)
                    }

                    CategoryColorPalettePicker(selectedHex: $newCategoryColorHex)

                    if store.settings.categories.isEmpty {
                        Text("No categories yet. Add one to make it available everywhere Orbit groups work.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
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
                }
            }
        }
    }

    private var hotkeysPage: some View {
        detailPage(for: .hotkeys) {
            preferencesSectionCard(
                title: "Global Shortcuts"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    hotkeyField(
                        title: "Session shortcut (open or start)",
                        prompt: "ctrl+option+cmd+k",
                        text: $store.settings.startShortcut
                    )

                    hotkeyField(
                        title: "Quick capture shortcut",
                        prompt: "ctrl+option+cmd+j",
                        text: $store.settings.captureShortcut
                    )

                    Divider()
                        .padding(.vertical, 2)

                    hotkeyField(
                        title: "Quick capture: next priority",
                        prompt: "cmd+.",
                        text: $store.settings.captureNextPriorityShortcut
                    )

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
        }
    }

    private var aboutPage: some View {
        detailPage(for: .about) {
            preferencesSectionCard(title: "App Information") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Orbit: A Focus Manager")
                        .font(.title3.weight(.semibold))
                    Text("Version \(appVersionString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            preferencesSectionCard(title: "Feature Snapshot") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built for focused work on macOS.")
                        .font(.body)

                    Text("Menu bar-first session management")
                    Text("Quick capture with markdown tasks")
                    Text("Task categories, filters, priorities, and session exports")
                    Text("Local-first SQLite persistence")
                }
                .font(.subheadline)
            }
        }
    }

    private var creditsPage: some View {
        detailPage(for: .credits) {
            preferencesSectionCard(
                title: "Third-Party Credits",
                subtitle: "\(ThirdPartyCredits.all.count) packages in Orbit's current SwiftPM dependency graph."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(ThirdPartyCredits.all) { credit in
                            ThirdPartyCreditCard(credit: credit)
                        }
                    }
                }
            }
        }
    }

    private func sections(in group: PreferencesSidebarGroup) -> [PreferencesSection] {
        PreferencesSection.allCases.filter { $0.group == group }
    }

    private func addCategoryButtonTapped() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        store.send(.settingsAddCategoryTapped(trimmedName, newCategoryColorHex))
        newCategoryName = ""
        newCategoryColorHex = FocusDefaults.defaultCategoryColorHex
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

    private func hotkeyField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func sidebarRow(for section: PreferencesSection) -> some View {
        Label(section.title, systemImage: section.symbolName)
            .font(.body.weight(.medium))
            .symbolRenderingMode(.hierarchical)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private func detailPage<Content: View>(
        for section: PreferencesSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.title.weight(.semibold))
                    Text(section.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func preferencesSectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        preferencesPanel {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                content()
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
    }

    @ViewBuilder
    private func preferencesPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
