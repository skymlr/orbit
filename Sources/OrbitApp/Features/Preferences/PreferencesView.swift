import ComposableArchitecture
import SwiftUI

struct PreferencesView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: PreferencesSection? = .categories
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = FocusDefaults.defaultCategoryColorHex

    private var sections: [PreferencesSection] {
        PreferencesSection.allCases.filter { section in
            switch section {
            case .hotkeys:
                return store.settings.showsHotkeySettings
            default:
                return true
            }
        }
    }

    private var activeSection: PreferencesSection {
        if let selectedSection, sections.contains(selectedSection) {
            return selectedSection
        }
        return sections.first ?? .categories
    }

    var body: some View {
        OrbitAdaptiveLayoutReader { layout in
            navigationContent(for: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .task {
                    store.send(.settingsRefreshTapped)
                }
                .background {
                    OrbitSpaceBackground()
                }
                .orbitOnExitCommand {
                    dismiss()
                }
        }
    }

    @ViewBuilder
    private func navigationContent(for layout: OrbitAdaptiveLayoutValue) -> some View {
        if layout.isCompact {
            compactNavigationContent
        } else {
            TabView(selection: tabSelection) {
                ForEach(sections) { section in
                    sectionContent(for: section)
                        .tabItem {
                            Label(section.title, systemImage: section.symbolName)
                        }
                        .tag(section)
                }
            }
        }
    }

    private var compactNavigationContent: some View {
        PreferencesCompactIndexView(sections: sections) { section in
            sectionContent(for: section)
        }
    }

    private var tabSelection: Binding<PreferencesSection> {
        Binding(
            get: { activeSection },
            set: { selectedSection = $0 }
        )
    }

    @ViewBuilder
    private func sectionContent(for section: PreferencesSection) -> some View {
        switch section {
        case .categories:
            categoriesPage
        case .hotkeys:
            hotkeysPage
        case .appearance:
            appearancePage
        case .sync:
            syncPage
        case .about:
            aboutPage
        case .credits:
            creditsPage
        }
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
                            .disabled(isAtCategoryLimit)

                        Button("Add") {
                            addCategoryButtonTapped()
                        }
                        .buttonStyle(.orbitSecondary)
                        .disabled(isAtCategoryLimit)
                    }

                    CategoryColorPalettePicker(selectedHex: $newCategoryColorHex)

                    if isAtCategoryLimit {
                        Text("Category limit reached. Orbit supports up to \(FocusDefaults.maxCategoryCount) categories.")
                            .orbitFont(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if store.settings.categories.isEmpty {
                        Text("No categories yet. Add one to make it available everywhere Orbit groups work.")
                            .orbitFont(.subheadline)
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
                        .orbitFont(.title3, weight: .semibold)
                    Text("Version \(appVersionString)")
                        .orbitFont(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(bundleIdentifier)
                        .orbitFont(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            preferencesSectionCard(title: "Feature Snapshot") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.platform.supportsMenuBar ? "Built for focused work on macOS." : "Built for focused work across Orbit's iPhone, iPad, and macOS experience.")
                        .orbitFont(.body)

                    Text("Menu bar-first session management")
                    Text("Quick capture with markdown tasks")
                    Text("Task categories, filters, priorities, and session exports")
                    Text("Local-first SQLite persistence")
                }
                .orbitFont(.subheadline)
            }
        }
    }

    private var syncPage: some View {
        detailPage(for: .sync) {
            preferencesSectionCard(
                title: "iCloud Sync",
                subtitle: "Mirror sessions, tasks, and categories across your Orbit devices with one opt-in toggle."
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Enable iCloud Sync", isOn: syncToggleBinding)
                    .toggleStyle(.switch)
                    .disabled(!store.platform.supportsCloudSync)

                    PreferencesSyncStatusCardView(
                        title: syncStatusTitle,
                        message: syncStatusMessage,
                        showsRetry: store.platform.supportsCloudSync && store.syncStatus.isRetryAvailable,
                        retryAction: {
                            store.send(.settingsCloudSyncRetryTapped)
                        }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What syncs")
                            .orbitFont(.caption)
                            .foregroundStyle(.secondary)

                        Text(
                            store.platform.supportsCloudSync
                                ? "Sessions, tasks, and categories sync through iCloud. Appearance and hotkeys stay local to this device."
                                : "This local unsigned build runs Orbit in local-only mode. Use the signed schemes to test iCloud sync."
                        )
                            .orbitFont(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var syncToggleBinding: Binding<Bool> {
        Binding(
            get: { store.platform.supportsCloudSync ? store.isCloudSyncEnabled : false },
            set: { store.send(.settingsCloudSyncToggled($0)) }
        )
    }

    private var syncStatusTitle: String {
        if store.platform.supportsCloudSync {
            return store.syncStatus.settingsTitle
        } else {
            return "iCloud sync is unavailable"
        }
    }

    private var syncStatusMessage: String {
        if store.platform.supportsCloudSync {
            return store.syncStatus.settingsMessage
        } else {
            return "The local unsigned scheme omits CloudKit entitlements, so Orbit stays local-only in this build."
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

    private var appearancePage: some View {
        detailPage(for: .appearance) {
            preferencesPanel {
                VStack(alignment: .leading, spacing: 16) {
                    appearanceSaveCallout

                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Typography")
                            .orbitFont(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Font", selection: $store.settings.appearanceDraft.font) {
                            ForEach(OrbitFontOption.allCases) { option in
                                fontOptionRow(for: option)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(appearancePickerStyle)
                        .labelsHidden()
                    }

                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Background")
                            .orbitFont(.caption)
                            .foregroundStyle(.secondary)

                        backgroundSelectionControl
                    }

                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Orbital Layer")
                            .orbitFont(.caption)
                            .foregroundStyle(.secondary)

                        Toggle(
                            "Show stars, orbits, planets, and sun",
                            isOn: $store.settings.appearanceDraft.showsOrbitalLayer
                        )
                        .toggleStyle(.switch)

                        Text(
                            store.settings.appearanceDraft.showsOrbitalLayer
                            ? "The orbital artwork will sit on top of the selected background."
                            : "Only the selected background color or material will be shown."
                        )
                        .orbitFont(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func addCategoryButtonTapped() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard !isAtCategoryLimit else { return }

        store.send(.settingsAddCategoryTapped(trimmedName, newCategoryColorHex))
        newCategoryName = ""
        newCategoryColorHex = FocusDefaults.defaultCategoryColorHex
    }

    private var isAtCategoryLimit: Bool {
        store.settings.categories.count >= FocusDefaults.maxCategoryCount
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

    private var appearancePickerStyle: some PickerStyle {
#if os(macOS)
        .radioGroup
#else
        .inline
#endif
    }

    private var hasUnsavedAppearanceChanges: Bool {
        store.settings.appearanceDraft != store.appearance
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "OrbitApp"
    }

    private func hotkeyField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
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
                        .orbitFont(.title, weight: .semibold)
                    Text(section.subtitle)
                        .orbitFont(.subheadline)
                        .foregroundStyle(.secondary)
                }

                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            OrbitSpaceBackground(
                style: store.appearance.background,
                showsOrbitalLayer: store.appearance.showsOrbitalLayer
            )
        }
#if os(macOS)
        .scrollEdgeEffectStyle(.hard, for: .top)
#endif
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
                        .orbitFont(.headline, weight: .semibold)

                    if let subtitle {
                        Text(subtitle)
                            .orbitFont(.subheadline)
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
        .orbitSurfaceCard(
            fillStyle: .thinMaterial,
            borderColor: OrbitTheme.Palette.glassBorder
        )
    }

    private var appearanceSaveCallout: some View {
        PreferencesAppearanceSaveCalloutView(
            hasUnsavedChanges: hasUnsavedAppearanceChanges,
            fill: appearanceCalloutFill,
            stroke: appearanceCalloutStroke,
            iconBackground: appearanceCalloutIconBackground,
            iconColor: appearanceCalloutIconColor,
            resetAction: {
                store.send(.settingsResetAppearanceTapped)
            },
            saveAction: {
                store.send(.settingsSaveAppearanceTapped)
            }
        )
    }

    private var appearanceCalloutFill: Color {
        colorScheme == .dark
            ? OrbitTheme.Palette.heroCyan.opacity(0.18)
            : OrbitTheme.Palette.lightPanelSoft.opacity(0.94)
    }

    private var appearanceCalloutStroke: Color {
        if hasUnsavedAppearanceChanges {
            return colorScheme == .dark
                ? OrbitTheme.Palette.orbitLine.opacity(0.58)
                : OrbitTheme.Palette.lightStroke.opacity(0.58)
        } else {
            return colorScheme == .dark
                ? OrbitTheme.Palette.glassBorderStrong.opacity(0.9)
                : OrbitTheme.Palette.lightStrokeSoft.opacity(0.42)
        }
    }

    private var appearanceCalloutIconBackground: Color {
        hasUnsavedAppearanceChanges
            ? OrbitTheme.Palette.sunHalo.opacity(colorScheme == .dark ? 0.24 : 0.30)
            : OrbitTheme.Palette.toastSuccess.opacity(colorScheme == .dark ? 0.22 : 0.26)
    }

    private var appearanceCalloutIconColor: Color {
        hasUnsavedAppearanceChanges
            ? OrbitTheme.Palette.sunCore
            : OrbitTheme.Palette.toastSuccess
    }

    private func fontOptionRow(for option: OrbitFontOption) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(option.title)
                .font(OrbitTypography.previewFont(for: option, style: .body, weight: .semibold))
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var backgroundSelectionControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(OrbitBackgroundOption.allCases) { option in
                backgroundOptionCard(for: option)
            }
        }
    }

    private func backgroundOptionCard(for option: OrbitBackgroundOption) -> some View {
        let isSelected = store.settings.appearanceDraft.background == option
        let showsOrbitalLayer = store.settings.appearanceDraft.showsOrbitalLayer

        return PreferencesBackgroundOptionCardView(
            option: option,
            showsOrbitalLayer: showsOrbitalLayer,
            isSelected: isSelected,
            previewSubtitle: backgroundPreviewSubtitle(
                for: option,
                showsOrbitalLayer: showsOrbitalLayer
            ),
            fillColor: backgroundOptionCardFill(isSelected: isSelected),
            strokeColor: backgroundOptionCardStroke(isSelected: isSelected),
            indicatorColor: backgroundOptionIndicatorColor(isSelected: isSelected),
            action: {
                store.settings.appearanceDraft.background = option
            }
        )
    }

    private func backgroundOptionCardFill(isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark
                ? OrbitTheme.Palette.heroCyan.opacity(0.24)
                : OrbitTheme.Palette.lightPanel.opacity(0.96)
        } else {
            return colorScheme == .dark
                ? OrbitTheme.Palette.glassFillSubtle
                : OrbitTheme.Palette.lightPanelSoft.opacity(0.88)
        }
    }

    private func backgroundOptionCardStroke(isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark
                ? OrbitTheme.Palette.orbitLine.opacity(0.62)
                : OrbitTheme.Palette.lightStroke.opacity(0.58)
        } else {
            return colorScheme == .dark
                ? OrbitTheme.Palette.glassBorderStrong.opacity(0.82)
                : OrbitTheme.Palette.lightStrokeSoft.opacity(0.36)
        }
    }

    private func backgroundOptionIndicatorColor(isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark
                ? OrbitTheme.Palette.orbitLine
                : OrbitTheme.Palette.lightStroke
        } else {
            return colorScheme == .dark
                ? OrbitTheme.Palette.priorityNone.opacity(0.82)
                : OrbitTheme.Palette.lightTextSecondary.opacity(0.72)
        }
    }

    private func backgroundPreviewSubtitle(
        for option: OrbitBackgroundOption,
        showsOrbitalLayer: Bool
    ) -> String {
        let suffix = showsOrbitalLayer
            ? " Orbital layer enabled."
            : " Orbital layer hidden."

        switch option {
        case .spaceBlue:
            return "Deep space-blue canvas with Orbit's darker nebula wash.\(suffix)"
        case .skyBlue:
            return "Brighter blue gradient with a lighter atmospheric feel.\(suffix)"
        case .purple:
            return "Blue-violet gradient that stays restrained and nocturnal.\(suffix)"
        case .glass:
            return "Translucent blur that lets the desktop behind the window come through.\(suffix)"
        }
    }
}
