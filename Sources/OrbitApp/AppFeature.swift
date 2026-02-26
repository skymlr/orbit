import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var currentMode: FocusMode = .coding
        var sessionItems: IdentifiedArrayOf<CapturedItem> = []
        var sessionStartTime: Date = .distantPast
        var menuBar = MenuBarFeature.State()
        @Presents var floatingPalette: FloatingPaletteFeature.State?
        @Presents var sessionReplay: SessionFeature.State?
        var recentItemsByMode: [FocusMode: IdentifiedArrayOf<CapturedItem>] = FocusMode.allCases.reduce(into: [:]) {
            $0[$1] = []
        }
        var hasLaunched = false

        var currentSession: Session {
            Session(
                mode: currentMode,
                startedAt: sessionStartTime,
                endedAt: nil,
                items: Array(sessionItems)
            )
        }
    }

    enum Action {
        case onLaunch
        case focusModeChanged(FocusMode)
        case captureItem(String)
        case itemCaptured(CapturedItem)
        case toggleFloatingPalette
        case endSession
        case menuBar(MenuBarFeature.Action)
        case floatingPalette(PresentationAction<FloatingPaletteFeature.Action>)
        case sessionReplay(PresentationAction<SessionFeature.Action>)
        case hotkeyTriggered
    }

    @Dependency(\.date.now) var now
    @Dependency(\.hotkeyManager) var hotkeyManager
    @Dependency(\.sessionStore) var sessionStore
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Scope(state: \.menuBar, action: \.menuBar) {
            MenuBarFeature()
        }

        Reduce { state, action in
            switch action {
            case .onLaunch:
                guard !state.hasLaunched else { return .none }
                state.hasLaunched = true
                if state.sessionStartTime == .distantPast {
                    state.sessionStartTime = now
                }
                return .run { send in
                    hotkeyManager.register("cmd+shift+o") {
                        Task {
                            await send(.hotkeyTriggered)
                        }
                    }
                }

            case .hotkeyTriggered:
                return .send(.toggleFloatingPalette)

            case let .focusModeChanged(mode):
                guard mode != state.currentMode else { return .none }

                let endedAt = now
                let completedSession = Session(
                    mode: state.currentMode,
                    startedAt: state.sessionStartTime,
                    endedAt: endedAt,
                    items: Array(state.sessionItems)
                )

                if !completedSession.items.isEmpty {
                    state.sessionReplay = SessionFeature.State(session: completedSession)
                }

                state.currentMode = mode
                state.sessionStartTime = endedAt
                state.sessionItems = []

                if state.floatingPalette != nil {
                    let recentItems = state.recentItemsByMode[mode, default: []]
                    state.floatingPalette?.currentMode = mode
                    state.floatingPalette?.recentItems = recentItems
                }

                return persistSessionIfNeeded(completedSession)

            case let .captureItem(rawInput):
                guard let item = CaptureInputParser.parse(
                    rawInput,
                    mode: state.currentMode,
                    timestamp: now,
                    id: uuid()
                ) else {
                    return .none
                }
                return .send(.itemCaptured(item))

            case let .itemCaptured(item):
                state.sessionItems.append(item)

                var modeItems = state.recentItemsByMode[item.mode, default: []]
                modeItems.remove(id: item.id)
                modeItems.insert(item, at: 0)
                if modeItems.count > 5 {
                    modeItems.removeLast(modeItems.count - 5)
                }
                state.recentItemsByMode[item.mode] = modeItems

                if state.floatingPalette != nil {
                    state.floatingPalette?.recentItems = modeItems
                }

                return persistSessionIfNeeded(state.currentSession)

            case .toggleFloatingPalette:
                if state.floatingPalette == nil {
                    state.floatingPalette = FloatingPaletteFeature.State(
                        currentMode: state.currentMode,
                        recentItems: state.recentItemsByMode[state.currentMode, default: []]
                    )
                } else {
                    state.floatingPalette = nil
                }
                return .none

            case .endSession:
                let endedAt = now
                let completedSession = Session(
                    mode: state.currentMode,
                    startedAt: state.sessionStartTime,
                    endedAt: endedAt,
                    items: Array(state.sessionItems)
                )

                if !completedSession.items.isEmpty {
                    state.sessionReplay = SessionFeature.State(session: completedSession)
                }

                state.sessionStartTime = endedAt
                state.sessionItems = []

                if state.floatingPalette != nil {
                    let recentItems = state.recentItemsByMode[state.currentMode, default: []]
                    state.floatingPalette?.recentItems = recentItems
                }

                return persistSessionIfNeeded(completedSession)

            case let .menuBar(.delegate(delegateAction)):
                switch delegateAction {
                case let .modeSelected(mode):
                    return .send(.focusModeChanged(mode))
                case .captureTapped:
                    return .send(.toggleFloatingPalette)
                case .endSessionTapped:
                    return .send(.endSession)
                case .preferencesTapped:
                    return .none
                }

            case let .floatingPalette(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .capture(text):
                    return .send(.captureItem(text))
                case .close:
                    state.floatingPalette = nil
                    return .none
                case let .pinToEdge(isPinned):
                    state.floatingPalette?.isPinnedToEdge = isPinned
                    return .none
                }

            case let .sessionReplay(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case .dismiss:
                    state.sessionReplay = nil
                    return .none

                case let .carryForward(items):
                    state.sessionReplay = nil

                    let carriedItems = items.map {
                        CapturedItem(
                            id: uuid(),
                            content: $0.content,
                            mode: state.currentMode,
                            timestamp: now,
                            type: $0.type
                        )
                    }

                    for item in carriedItems {
                        state.sessionItems.append(item)
                    }

                    var modeItems = state.recentItemsByMode[state.currentMode, default: []]
                    for item in carriedItems.reversed() {
                        modeItems.insert(item, at: 0)
                    }
                    if modeItems.count > 5 {
                        modeItems.removeLast(modeItems.count - 5)
                    }
                    state.recentItemsByMode[state.currentMode] = modeItems
                    state.floatingPalette?.recentItems = modeItems

                    return persistSessionIfNeeded(state.currentSession)

                case let .export(session):
                    return .run { _ in
                        try? await sessionStore.save(session)
                    }
                }

            case .menuBar:
                return .none

            case .floatingPalette:
                return .none

            case .sessionReplay:
                return .none
            }
        }
        .ifLet(\.$floatingPalette, action: \.floatingPalette) {
            FloatingPaletteFeature()
        }
        .ifLet(\.$sessionReplay, action: \.sessionReplay) {
            SessionFeature()
        }
    }

    private func persistSessionIfNeeded(_ session: Session) -> Effect<Action> {
        guard !session.items.isEmpty else { return .none }

        return .run { _ in
            try? await sessionStore.save(session)
        }
    }
}
