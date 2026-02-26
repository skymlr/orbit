import ComposableArchitecture

@Reducer
struct MenuBarFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case modeSelected(FocusMode)
        case captureTapped
        case endSessionTapped
        case preferencesTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case modeSelected(FocusMode)
        case captureTapped
        case endSessionTapped
        case preferencesTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .modeSelected(mode):
                return .send(.delegate(.modeSelected(mode)))

            case .captureTapped:
                return .send(.delegate(.captureTapped))

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
