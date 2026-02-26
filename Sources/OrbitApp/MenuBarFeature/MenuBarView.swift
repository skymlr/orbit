import ComposableArchitecture
import SwiftUI
import AppKit

struct MenuBarView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.openWindow) private var openWindow

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

                Button {
                    openSettingsWindow()
                } label: {
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
                        openSessionWindow()
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
            EndSessionPromptView(
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

private extension MenuBarView {
    func openSessionWindow() {
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

    func openSettingsWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "settings-window")

        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Orbit Settings" }) else {
                return
            }
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

}
