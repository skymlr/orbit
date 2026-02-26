import ComposableArchitecture
import Foundation
import Testing
@testable import OrbitApp

@MainActor
struct AppFeatureTests {
    @Test
    func modeSwitchUpdatesStateAndCreatesReplay() async {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let now = Date(timeIntervalSince1970: 1_700_000_300)
        let existingItem = CapturedItem(
            id: UUID(0),
            content: "Write tests for edge cases",
            mode: .coding,
            timestamp: start,
            type: .todo
        )

        var initialState = AppFeature.State()
        initialState.currentMode = .coding
        initialState.sessionStartTime = start
        initialState.sessionItems = [existingItem]

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.date.now = now
            $0.sessionStore.save = { _ in }
            $0.hotkeyManager.register = { _, _ in }
            $0.uuid = .incrementing
        }

        let expectedSession = Session(
            mode: .coding,
            startedAt: start,
            endedAt: now,
            items: [existingItem]
        )

        await store.send(.focusModeChanged(.researching)) {
            $0.currentMode = .researching
            $0.sessionStartTime = now
            $0.sessionItems = []
            $0.sessionReplay = SessionFeature.State(session: expectedSession)
        }
    }

    @Test
    func toggleFloatingPaletteShowHide() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.sessionStore.save = { _ in }
            $0.hotkeyManager.register = { _, _ in }
        }

        await store.send(.toggleFloatingPalette) {
            $0.floatingPalette = FloatingPaletteFeature.State(
                currentMode: .coding,
                recentItems: []
            )
        }

        await store.send(.toggleFloatingPalette) {
            $0.floatingPalette = nil
        }
    }
}

private extension UUID {
    init(_ value: UInt8) {
        self.init(uuid: (
            value, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ))
    }
}
