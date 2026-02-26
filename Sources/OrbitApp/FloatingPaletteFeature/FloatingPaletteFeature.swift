import ComposableArchitecture

@Reducer
struct FloatingPaletteFeature {
    @ObservableState
    struct State: Equatable {
        var inputText = ""
        var sessionTitle: String?
        var tags: [SessionTag] = []
        var recentItems: IdentifiedArrayOf<CapturedItem> = []

        var hasActiveSession: Bool {
            sessionTitle != nil
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case closeTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction {
        case capture(String)
        case close
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

            case .delegate:
                return .none
            }
        }
    }
}
