import ComposableArchitecture
import SwiftUI

struct MenuBarView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        let menuStore = store.scope(state: \.menuBar, action: \.menuBar)

        VStack(alignment: .leading, spacing: sectionSpacing(for: store.currentMode)) {
            HStack(spacing: 8) {
                Image(systemName: store.currentMode.config.symbolName)
                    .foregroundStyle(store.currentMode.config.tint)
                Text("\(store.currentMode.config.displayName) Mode")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Switch Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(FocusMode.allCases, id: \.self) { mode in
                        Button {
                            menuStore.send(.modeSelected(mode))
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.config.symbolName)
                                Text(mode.config.displayName)
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .foregroundStyle(mode == store.currentMode ? .white : .primary)
                            .background(mode == store.currentMode ? mode.config.tint : Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(store.floatingPalette == nil ? "Capture" : "Hide Capture") {
                menuStore.send(.captureTapped)
            }

            Button("End Session") {
                menuStore.send(.endSessionTapped)
            }

            Divider()

            Button("Preferences") {
                menuStore.send(.preferencesTapped)
            }
        }
        .padding(12)
        .frame(width: 340)
        .sheet(item: $store.scope(state: \.sessionReplay, action: \.sessionReplay)) { replayStore in
            SessionReplayView(store: replayStore)
        }
    }

    private func sectionSpacing(for mode: FocusMode) -> CGFloat {
        switch mode.config.density {
        case .compact: return 10
        case .regular: return 14
        case .expanded: return 18
        }
    }
}
