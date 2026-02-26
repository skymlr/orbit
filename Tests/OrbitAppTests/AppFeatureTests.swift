import ComposableArchitecture
import Foundation
import Testing
@testable import OrbitApp

@MainActor
struct AppFeatureTests {
    @Test
    func endSessionTappedCreatesDraft() async {
        let active = makeActiveSession()
        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = [
            SessionCategoryRecord(
                id: FocusDefaults.focusCategoryID,
                name: FocusDefaults.focusCategoryName,
                normalizedName: FocusDefaults.focusCategoryName
            )
        ]

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.endSessionTapped) {
            $0.endSessionDraft = AppFeature.State.EndSessionDraft(
                id: UUID(0),
                name: active.name,
                selectedCategoryID: active.categoryID,
                categories: initial.categories
            )
        }
    }

    @Test
    func captureWindowClosedResetsDraftAndWindow() async {
        var initial = AppFeature.State()
        initial.captureDraft.text = "Investigate perf regression"
        initial.captureDraft.tags = "perf"
        initial.captureDraft.priority = .high
        initial.windowDestinations.insert(.captureWindow)

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.captureWindowClosed) {
            $0.captureDraft = AppFeature.State.CaptureDraft()
            $0.windowDestinations.remove(.captureWindow)
        }
    }

    @Test
    func exportSelectionToggles() async {
        let sessionID = UUID(uuidString: "E7C77F3E-37F4-4ADF-B8D5-662D4E43B5A1")!

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.settingsToggleExportSelection(sessionID)) {
            $0.settings.exportSelection = [sessionID]
        }

        await store.send(.settingsToggleExportSelection(sessionID)) {
            $0.settings.exportSelection = []
        }
    }

    @Test
    func loadingAndClearingActiveSessionSynchronizesDraftsAndWindows() async {
        let active = makeActiveSession()

        var initial = AppFeature.State()
        initial.windowDestinations = [.captureWindow, .sessionWindow]

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.loadActiveSessionResponse(active)) {
            $0.activeSession = active
            $0.noteDrafts = [
                AppFeature.State.NoteDraft(
                    id: active.notes[0].id,
                    text: active.notes[0].text,
                    tags: active.notes[0].tags.joined(separator: ", "),
                    priority: active.notes[0].priority
                )
            ]
        }

        await store.send(.loadActiveSessionResponse(nil)) {
            $0.activeSession = nil
            $0.noteDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
        }
    }
}

private func makeActiveSession() -> FocusSessionRecord {
    let note = FocusNoteRecord(
        id: UUID(uuidString: "A6E2C2D2-53AF-4D10-ACE2-761B700A1DB1")!,
        sessionID: UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!,
        text: "Ship Orbit session window",
        priority: .high,
        tags: ["shipping", "ui"],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    return FocusSessionRecord(
        id: note.sessionID,
        name: "2026-02-26 10:30",
        categoryID: FocusDefaults.focusCategoryID,
        categoryName: FocusDefaults.focusCategoryName,
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        endedAt: nil,
        endedReason: nil,
        notes: [note]
    )
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
