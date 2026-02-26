import ComposableArchitecture
import SwiftUI

struct FloatingPaletteView: View {
    @SwiftUI.Bindable var store: StoreOf<FloatingPaletteFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(store.currentMode.config.displayName, systemImage: store.currentMode.config.symbolName)
                    .font(.caption)
                    .foregroundStyle(store.currentMode.config.tint)

                Spacer()

                Button {
                    store.send(.pinToEdgeTapped)
                } label: {
                    Image(systemName: store.isPinnedToEdge ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)

                Button {
                    store.send(.closeTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }

            TextField(
                store.currentMode.config.capturePlaceholder,
                text: $store.inputText
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                store.send(.submitTapped)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(store.recentItems.prefix(5)) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text(item.type.prefix)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Text(item.content)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320, height: 150)
        .background(.thinMaterial)
    }
}
