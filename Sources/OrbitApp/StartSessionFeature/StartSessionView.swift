import ComposableArchitecture
import SwiftUI

struct StartSessionView: View {
    @SwiftUI.Bindable var store: StoreOf<StartSessionFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start Focus Session")
                .font(.title2.bold())

            if store.launchedFromCapture {
                Text("Your pending capture will be saved as soon as the session starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Focus Session", text: $store.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.availableTags) { tag in
                            Button {
                                store.send(.toggleTag(tag.id))
                            } label: {
                                Text(tag.name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(store.selectedTagIDs.contains(tag.id) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: 8) {
                TextField("Add custom tag", text: $store.customTagInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        store.send(.addCustomTagTapped)
                    }

                Button("Add") {
                    store.send(.addCustomTagTapped)
                }
            }

            HStack {
                Spacer()
                Button("Start Session") {
                    store.send(.startTapped)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 420)
    }
}
