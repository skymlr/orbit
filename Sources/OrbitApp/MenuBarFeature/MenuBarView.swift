import ComposableArchitecture
import SwiftUI

struct MenuBarView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Orbit: A Focus Manager")
                        .font(.headline)
                    if let activeSession = store.activeSession {
                        Text("Started \(activeSession.startedAt, style: .time) • \(activeSession.startedAt, style: .timer)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No active session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            if let statusMessage = store.settings.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let activeSession = store.activeSession {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activeSession.name)
                        .font(.title3.weight(.semibold))
                    Text("Category: \(activeSession.categoryName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button("Open Session") {
                        store.send(.openSessionTapped)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Capture") {
                        store.send(.captureTapped)
                    }
                }

                Button("End Session") {
                    store.send(.endSessionTapped)
                }
            } else {
                Button("Start Session") {
                    store.send(.startSessionTapped)
                }
                .buttonStyle(.borderedProminent)

                Button("Quick Capture") {
                    store.send(.captureTapped)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .sheet(item: $store.endSessionDraft) { draft in
            EndSessionSheet(
                draft: draft,
                onConfirm: { name, categoryID in
                    store.send(.endSessionConfirmTapped(name: name, categoryID: categoryID))
                },
                onCancel: {
                    store.send(.endSessionCancelTapped)
                }
            )
        }
    }
}

private struct EndSessionSheet: View {
    let draft: AppFeature.State.EndSessionDraft
    let onConfirm: (String, UUID?) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var selectedCategoryID = FocusDefaults.focusCategoryID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("End Focus Session")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Session name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Category", selection: $selectedCategoryID) {
                    ForEach(draft.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }

                Spacer()

                Button("End Session") {
                    onConfirm(name, selectedCategoryID)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(.thinMaterial)
        .task {
            name = draft.name
            selectedCategoryID = draft.selectedCategoryID
        }
    }
}
