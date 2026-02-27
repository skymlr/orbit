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
                    Button {
                        store.send(.startSessionTapped)
                        openSessionWindow()
                    } label: {
                        hotkeyButtonLabel(
                            title: "Session",
                            shortcut: store.hotkeys.startShortcut
                        )
                    }
                    .buttonStyle(.orbitPrimary)
                    .help("Open or Start Session \(HotkeyHintFormatter.hint(from: store.hotkeys.startShortcut))")

                    Button {
                        store.send(.captureTapped)
                    } label: {
                        hotkeyButtonLabel(
                            title: "Capture",
                            shortcut: store.hotkeys.captureShortcut
                        )
                    }
                    .buttonStyle(.orbitSecondary)
                }

                Button("End Session") {
                    store.send(.endSessionTapped)
                }
                .buttonStyle(.orbitQuiet)
            } else {
                Button {
                    store.send(.startSessionTapped)
                } label: {
                    sessionHeroLabel(shortcut: store.hotkeys.startShortcut)
                }
                .buttonStyle(.orbitHero)
                .help("Open or Start Session \(HotkeyHintFormatter.hint(from: store.hotkeys.startShortcut))")
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
    @ViewBuilder
    func sessionHeroLabel(shortcut: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "atom")
                    .font(.title3.weight(.semibold))
                Text("Open or Start Session")
                    .font(.title3.weight(.bold))
                Spacer()
                HotkeyHintLabel(shortcut: shortcut, tone: .inverted)
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            Text("Open your focus orbit or ignite a new one")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.86))
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    func hotkeyButtonLabel(title: String, shortcut: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            HotkeyHintLabel(shortcut: shortcut)
        }
    }

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
