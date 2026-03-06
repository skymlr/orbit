import ComposableArchitecture
import SwiftUI

struct MenuBarView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.dismiss) private var dismiss

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
            }

            if let activeSession = store.activeSession {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activeSession.name)
                            .font(.title3.weight(.semibold))
                    }

                    HStack(spacing: 10) {
                        Button {
                            dismissMenuThen {
                                store.send(.startSessionTapped)
                            }
                        } label: {
                            hotkeyButtonLabel(
                                title: "Session",
                                shortcut: store.hotkeys.startShortcut
                            )
                        }
                        .buttonStyle(.orbitPrimary)
                        .help("Open or Start Session \(HotkeyHintFormatter.hint(from: store.hotkeys.startShortcut))")

                        Button {
                            dismissMenuThen {
                                store.send(.captureTapped)
                            }
                        } label: {
                            hotkeyButtonLabel(
                                title: "Capture",
                                shortcut: store.hotkeys.captureShortcut
                            )
                        }
                        .buttonStyle(.orbitSecondary)
                    }
                }
                .transition(.orbitMicro)
            } else {
                Button {
                    dismissMenuThen {
                        store.send(.startSessionTapped)
                    }
                } label: {
                    sessionHeroLabel(shortcut: store.hotkeys.startShortcut)
                }
                .buttonStyle(.orbitHero)
                .help("Start Session \(HotkeyHintFormatter.hint(from: store.hotkeys.startShortcut))")
                .transition(.orbitMicro)
            }
        }
        .padding(14)
        .frame(width: 360)
        .animation(.easeInOut(duration: OrbitTheme.Motion.standard), value: store.activeSession?.id)
        .background {
            ZStack {
                OrbitSpaceBackground()

                RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.44))

                RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                    .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous))
        }
    }
}

private extension MenuBarView {
    func dismissMenuThen(_ action: @escaping () -> Void) {
        dismiss()
        action()
    }

    @ViewBuilder
    func sessionHeroLabel(shortcut: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "atom")
                    .font(.title3.weight(.semibold))
                Text("Start Session")
                    .font(.title3.weight(.bold))
                Spacer()
                HotkeyHintLabel(shortcut: shortcut, tone: .inverted)
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            Text("Ignite a new focus orbit")
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
}
