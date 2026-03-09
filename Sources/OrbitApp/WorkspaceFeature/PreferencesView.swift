import ComposableArchitecture
import SwiftUI

struct PreferencesView: View {
    private enum Layout {
        static let sectionWidth: CGFloat = 700
    }

    private enum PreferencesSection: String, CaseIterable, Identifiable {
        case categories = "Categories"
        case hotkeys = "Hotkeys"
        case about = "About"
        case credits = "Credits"

        var id: String { rawValue }
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var selectedSection: PreferencesSection = .categories
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = FocusDefaults.defaultCategoryColorHex

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionPicker
            detailContent
        }
        .task {
            store.send(.settingsRefreshTapped)
        }
        .padding(20)
        .frame(minWidth: 920, minHeight: 680)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background {
            OrbitSpaceBackground()
        }
    }

    @ViewBuilder
    private func selectedSectionContent(for section: PreferencesSection) -> some View {
        switch section {
        case .categories:
            categoriesSection
        case .hotkeys:
            hotkeysSection
        case .about:
            aboutSection
        case .credits:
            creditsSection
        }
    }

    private var sectionPicker: some View {
        OrbitSegmentedControl(
            "Preferences Section",
            selection: $selectedSection,
            options: PreferencesSection.allCases
        ) { section in
            section.rawValue
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                selectedSectionContent(for: selectedSection)
                    .id(selectedSection)
                    .transition(.orbitMicro)
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.18), value: selectedSection)
    }

    private var hotkeysSection: some View {
        preferencesPanel {
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
        preferencesPanel {
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
        aboutSummaryCard
        .frame(maxWidth: sectionMaxWidth(for: .about))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var creditsSection: some View {
        thirdPartyCreditsCard
            .frame(maxWidth: sectionMaxWidth(for: .credits))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var aboutSummaryCard: some View {
        preferencesPanel {
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
    }

    private var thirdPartyCreditsCard: some View {
        preferencesPanel {
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

    private func addCategoryButtonTapped() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        store.send(.settingsAddCategoryTapped(trimmedName, newCategoryColorHex))
        newCategoryName = ""
        newCategoryColorHex = FocusDefaults.defaultCategoryColorHex
    }

    private func sectionMaxWidth(for section: PreferencesSection) -> CGFloat {
        Layout.sectionWidth
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
