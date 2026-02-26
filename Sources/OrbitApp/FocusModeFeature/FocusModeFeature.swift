import ComposableArchitecture

@Reducer
struct FocusModeFeature {
    @ObservableState
    struct State: Equatable {
        var selectedMode: FocusMode = .coding
    }

    enum Action {
        case selectMode(FocusMode)
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case modeChanged(FocusMode)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selectMode(mode):
                state.selectedMode = mode
                return .send(.delegate(.modeChanged(mode)))

            case .delegate:
                return .none
            }
        }
    }
}
