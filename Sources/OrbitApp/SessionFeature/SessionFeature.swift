import ComposableArchitecture
import Foundation

@Reducer
struct SessionFeature {
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
        var filter: Filter = .all
        var completedIDs: Set<CapturedItem.ID> = []
        var carryForwardIDs: Set<CapturedItem.ID> = []

        var filteredItems: [CapturedItem] {
            guard let type = filter.itemType else { return session.items }
            return session.items.filter { $0.type == type }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case carryForwardTapped
        case exportTapped
        case dismissTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case dismiss
        case carryForward([CapturedItem])
        case export(Session)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                state.carryForwardIDs.subtract(state.completedIDs)
                return .none

            case .carryForwardTapped:
                let items = state.session.items.filter {
                    state.carryForwardIDs.contains($0.id) && !state.completedIDs.contains($0.id)
                }
                return .send(.delegate(.carryForward(items)))

            case .exportTapped:
                return .send(.delegate(.export(state.session)))

            case .dismissTapped:
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }
}
