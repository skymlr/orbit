import ComposableArchitecture
import Foundation

@Reducer
struct StartSessionFeature {
    @ObservableState
    struct State: Equatable {
        var title: String = "Focus Session"
        var availableTags: [SessionTag] = SessionTag.builtIns
        var selectedTagIDs: Set<SessionTag.ID> = []
        var customTagInput = ""
        var launchedFromCapture = false

        var selectedTags: [SessionTag] {
            availableTags.filter { selectedTagIDs.contains($0.id) }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggleTag(SessionTag.ID)
        case addCustomTagTapped
        case startTapped
        case cancelTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case startConfirmed(title: String, tags: [SessionTag], catalog: [SessionTag])
        case cancelled
    }

    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .toggleTag(tagID):
                if state.selectedTagIDs.contains(tagID) {
                    state.selectedTagIDs.remove(tagID)
                } else {
                    state.selectedTagIDs.insert(tagID)
                }
                return .none

            case .addCustomTagTapped:
                let normalized = state.customTagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty else { return .none }

                if let existing = state.availableTags.first(where: { $0.normalizedName == normalized }) {
                    state.selectedTagIDs.insert(existing.id)
                } else {
                    let tag = SessionTag(id: uuid(), name: normalized, isBuiltIn: false)
                    state.availableTags.append(tag)
                    state.availableTags = sortCatalog(state.availableTags)
                    state.selectedTagIDs.insert(tag.id)
                }

                state.customTagInput = ""
                return .none

            case .startTapped:
                let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedTitle = title.isEmpty ? "Focus Session" : title
                return .send(
                    .delegate(
                        .startConfirmed(
                            title: normalizedTitle,
                            tags: state.selectedTags,
                            catalog: state.availableTags
                        )
                    )
                )

            case .cancelTapped:
                return .send(.delegate(.cancelled))

            case .delegate:
                return .none
            }
        }
    }

    private func sortCatalog(_ tags: [SessionTag]) -> [SessionTag] {
        let builtIns = tags.filter(\.isBuiltIn).sorted(by: { $0.name < $1.name })
        let custom = tags.filter { !$0.isBuiltIn }.sorted(by: { $0.name < $1.name })
        return builtIns + custom
    }
}
