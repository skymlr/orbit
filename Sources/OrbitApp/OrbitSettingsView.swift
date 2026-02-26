import AppKit
import ComposableArchitecture
import SwiftUI

struct OrbitSettingsView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hotkeysSection
                categoriesSection
                sessionsSection
                exportSection

                if let message = store.settings.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.09),
                    Color(red: 0.08, green: 0.12, blue: 0.19)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.2)
        )
    }

    private var hotkeysSection: some View {
        sectionCard(title: "Hotkeys") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Session Shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("cmd+shift+s", text: $store.settings.startShortcut)
                    .textFieldStyle(.roundedBorder)

                Text("Quick Capture Shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("cmd+shift+o", text: $store.settings.captureShortcut)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Save Hotkeys") {
                        store.send(.settingsSaveHotkeysTapped)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var categoriesSection: some View {
        sectionCard(title: "Categories") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Add category", text: $store.settings.newCategoryName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        store.send(.settingsAddCategoryTapped)
                    }
                }

                ForEach(store.settings.categories) { category in
                    CategoryRow(
                        category: category,
                        onRename: { newName in
                            store.send(.settingsRenameCategoryTapped(category.id, newName))
                        },
                        onDelete: {
                            store.send(.settingsDeleteCategoryTapped(category.id))
                        }
                    )
                }
            }
        }
    }

    private var sessionsSection: some View {
        sectionCard(title: "Sessions") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.settings.sessions) { session in
                    SessionRow(
                        session: session,
                        isSelectedForExport: store.settings.exportSelection.contains(session.id),
                        onRename: { newName in
                            store.send(.settingsRenameSessionTapped(session.id, newName))
                        },
                        onDelete: {
                            store.send(.settingsDeleteSessionTapped(session.id))
                        },
                        onToggleExport: {
                            store.send(.settingsToggleExportSelection(session.id))
                        }
                    )
                }
            }
        }
    }

    private var exportSection: some View {
        sectionCard(title: "Export Markdown") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected sessions: \(store.settings.exportSelection.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Export Selected Sessions") {
                    exportSelectedSessions()
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.settings.exportSelection.isEmpty)
            }
        }
    }

    private func exportSelectedSessions() {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"

        if panel.runModal() == .OK, let url = panel.url {
            store.send(.settingsExportTapped(url))
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct CategoryRow: View {
    let category: SessionCategoryRecord
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var name = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("Category", text: $name)
                .textFieldStyle(.roundedBorder)
            Button("Rename") {
                onRename(name)
            }
            .disabled(category.id == FocusDefaults.focusCategoryID)

            Button("Delete", role: .destructive) {
                onDelete()
            }
            .disabled(category.id == FocusDefaults.focusCategoryID)
        }
        .task(id: category.id) {
            name = category.name
        }
    }
}

private struct SessionRow: View {
    let session: FocusSessionRecord
    let isSelectedForExport: Bool
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onToggleExport: () -> Void

    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Session name", text: $name)
                    .textFieldStyle(.roundedBorder)

                Button("Rename") {
                    onRename(name)
                }

                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }

            HStack(spacing: 8) {
                Button {
                    onToggleExport()
                } label: {
                    Image(systemName: isSelectedForExport ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)

                Text(session.categoryName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Started \(session.startedAt, style: .date) \(session.startedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
        .task(id: session.id) {
            name = session.name
        }
    }
}
