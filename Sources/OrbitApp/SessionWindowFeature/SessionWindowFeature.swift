import ComposableArchitecture

@Reducer
struct SessionWindowFeature {
    @ObservableState
    struct State: Equatable {
        enum Filter: String, CaseIterable, Equatable, Identifiable, Sendable {
            case all
            case todo
            case next
            case note
            case link

            var id: String { rawValue }

            var itemType: ItemType? {
                switch self {
                case .all: return nil
                case .todo: return .todo
                case .next: return .next
                case .note: return .note
                case .link: return .link
                }
            }

            var title: String {
                switch self {
                case .all: return "All"
                case .todo: return "@todo"
                case .next: return "@next"
                case .note: return "@note"
                case .link: return "@link"
                }
            }
        }

        var session: Session
        var availableTags: [SessionTag]
        var inputText = ""
        var customTagInput = ""
        var filter: Filter = .all

        var filteredItems: [CapturedItem] {
            let source = session.items.sorted(by: { $0.timestamp > $1.timestamp })
            guard let type = filter.itemType else { return source }
            return source.filter { $0.type == type }
        }

        var suggestedTags: [SessionTag] {
            let selected = Set(session.tags.map(\.id))
            return availableTags.filter { !selected.contains($0.id) }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case closeTapped
        case removeTagTapped(SessionTag.ID)
        case addSuggestedTagTapped(SessionTag.ID)
        case addCustomTagTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case capture(String)
        case close
        case removeTag(SessionTag.ID)
        case addTagByID(SessionTag.ID)
        case addCustomTag(String)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .submitTapped:
                let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return .none }
                state.inputText = ""
                return .send(.delegate(.capture(text)))

            case .closeTapped:
                return .send(.delegate(.close))

            case let .removeTagTapped(tagID):
                return .send(.delegate(.removeTag(tagID)))

            case let .addSuggestedTagTapped(tagID):
                return .send(.delegate(.addTagByID(tagID)))

            case .addCustomTagTapped:
                let tag = state.customTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !tag.isEmpty else { return .none }
                state.customTagInput = ""
                return .send(.delegate(.addCustomTag(tag)))

            case .delegate:
                return .none
            }
        }
    }
}
