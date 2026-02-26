import ComposableArchitecture

@Reducer
struct FloatingPaletteFeature {
    @ObservableState
    struct State: Equatable {
        var currentMode: FocusMode
        var inputText = ""
        var recentItems: IdentifiedArrayOf<CapturedItem> = []
        var isPinnedToEdge = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case closeTapped
        case pinToEdgeTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case capture(String)
        case close
        case pinToEdge(Bool)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .submitTapped:
                let trimmed = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }

                state.inputText = ""
                return .send(.delegate(.capture(trimmed)))

            case .closeTapped:
                return .send(.delegate(.close))

            case .pinToEdgeTapped:
                state.isPinnedToEdge.toggle()
                return .send(.delegate(.pinToEdge(state.isPinnedToEdge)))

            case .delegate:
                return .none
            }
        }
    }
}
