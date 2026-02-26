import ComposableArchitecture
import SwiftUI

struct FloatingPaletteView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Button {
                    store.send(.captureWindowClosed)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }

            if let activeSession = store.activeSession {
                Text("\(activeSession.name) • \(activeSession.categoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TextField("Capture note text", text: $store.captureDraft.text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 4)

            TextField("Tags (comma-separated, optional)", text: $store.captureDraft.tags)
                .textFieldStyle(.roundedBorder)

            Picker("Priority", selection: $store.captureDraft.priority) {
                ForEach(NotePriority.allCases, id: \.self) { priority in
                    Text(priority.title).tag(priority)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Save") {
                    store.send(.captureSubmitTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.captureDraft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
