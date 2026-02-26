import ComposableArchitecture
import SwiftUI

struct SessionReplayView: View {
    @SwiftUI.Bindable var store: StoreOf<SessionFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Replay")
                        .font(.title2.bold())
                    Text("\(store.session.mode.config.displayName) - \(SessionDateFormatters.header.string(from: store.session.startedAt))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") {
                    store.send(.dismissTapped)
                }
            }

            Picker("Filter", selection: $store.filter) {
                ForEach(SessionFeature.State.Filter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            List {
                ForEach(store.filteredItems) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(SessionDateFormatters.time.string(from: item.timestamp)) - \(item.type.prefix)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Toggle("Done", isOn: $store.completedIDs[contains: item.id])
                                .toggleStyle(.checkbox)

                            Toggle("Carry", isOn: $store.carryForwardIDs[contains: item.id])
                                .toggleStyle(.checkbox)
                                .disabled(store.completedIDs.contains(item.id))
                        }

                        Text(item.content)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                Button("Export Markdown") {
                    store.send(.exportTapped)
                }

                Spacer()

                Button("Carry Forward Selected") {
                    store.send(.carryForwardTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.carryForwardIDs.isEmpty)
            }
        }
        .padding(18)
        .frame(minWidth: 640, minHeight: 420)
    }
}

private enum SessionDateFormatters {
    static let header: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private extension Set where Element: Hashable {
    subscript(contains element: Element) -> Bool {
        get { self.contains(element) }
        set {
            if newValue {
                insert(element)
            } else {
                remove(element)
            }
        }
    }
}
