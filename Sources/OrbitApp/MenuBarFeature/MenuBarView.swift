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

                    Button {
                        store.send(.captureTapped)
                    } label: {
                        hotkeyButtonLabel(
                            title: "Capture",
                            shortcut: store.hotkeys.captureShortcut
                        )
                    }
                }

                Button("End Session") {
                    store.send(.endSessionTapped)
                }
            } else {
                Button {
                    store.send(.startSessionTapped)
                } label: {
                    startSessionHeroLabel(shortcut: store.hotkeys.startShortcut)
                }
                .buttonStyle(.plain)
                .help("Start Session \(hotkeyHint(from: store.hotkeys.startShortcut))")
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
    func startSessionHeroLabel(shortcut: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.14, blue: 0.24),
                            Color(red: 0.02, green: 0.29, blue: 0.40),
                            Color(red: 0.24, green: 0.19, blue: 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.95),
                                    Color.orange.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.3
                        )
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "atom")
                        .font(.title3.weight(.semibold))
                    Text("Start Session")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text(hotkeyHint(from: shortcut))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text("Ignite a new focus orbit")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.86))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .shadow(color: Color.cyan.opacity(0.25), radius: 10, y: 4)
    }

    @ViewBuilder
    func hotkeyButtonLabel(title: String, shortcut: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Text(hotkeyHint(from: shortcut))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    func hotkeyHint(from shortcut: String) -> String {
        let components = shortcut
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard let keyPart = components.last, !keyPart.isEmpty else {
            return shortcut.uppercased()
        }

        let modifiers = Set(components.dropLast())
        let control = modifiers.contains("ctrl") || modifiers.contains("control")
        let option = modifiers.contains("option") || modifiers.contains("opt") || modifiers.contains("alt")
        let shift = modifiers.contains("shift")
        let command = modifiers.contains("cmd") || modifiers.contains("command")

        var glyphs = ""
        if control { glyphs += "⌃" }
        if option { glyphs += "⌥" }
        if shift { glyphs += "⇧" }
        if command { glyphs += "⌘" }

        return glyphs + keyGlyph(for: String(keyPart))
    }

    func keyGlyph(for key: String) -> String {
        switch key.lowercased() {
        case "space":
            return "Space"
        case "return", "enter":
            return "↩"
        case "tab":
            return "⇥"
        case "escape", "esc":
            return "⎋"
        case "delete", "backspace":
            return "⌫"
        case "up":
            return "↑"
        case "down":
            return "↓"
        case "left":
            return "←"
        case "right":
            return "→"
        default:
            return key.uppercased()
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
