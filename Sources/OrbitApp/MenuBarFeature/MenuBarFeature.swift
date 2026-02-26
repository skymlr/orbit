import ComposableArchitecture

@Reducer
struct MenuBarFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case startSessionTapped
        case captureTapped
        case openSessionTapped
        case endSessionTapped
        case preferencesTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case startSessionTapped
        case captureTapped
        case openSessionTapped
        case endSessionTapped
        case preferencesTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .startSessionTapped:
                return .send(.delegate(.startSessionTapped))

            case .captureTapped:
                return .send(.delegate(.captureTapped))

            case .openSessionTapped:
                return .send(.delegate(.openSessionTapped))

            case .endSessionTapped:
                return .send(.delegate(.endSessionTapped))

            case .preferencesTapped:
                return .send(.delegate(.preferencesTapped))

            case .delegate:
                return .none
            }
        }
    }
}
