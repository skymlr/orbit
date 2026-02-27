import ComposableArchitecture
import Foundation
import Testing
@testable import OrbitApp

@MainActor
struct AppFeatureTests {
    @Test
    func sessionNoteEditTappedPrefillsCaptureAndOpensWindow() async {
        let active = makeActiveSession()
        let note = active.notes[0]

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.noteDrafts = [
            AppFeature.State.NoteDraft(
                id: note.id,
                text: note.text,
                tags: note.tags,
                priority: note.priority,
                createdAt: note.createdAt
            )
        ]

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.sessionNoteEditTapped(note.id)) {
            $0.captureDraft.text = note.text
            $0.captureDraft.tags = note.tags.joined(separator: ", ")
            $0.captureDraft.priority = note.priority
            $0.captureDraft.editingNoteID = note.id
            $0.windowDestinations.insert(.captureWindow)
        }
    }

    @Test
    func sessionAddNoteTappedResetsEditContext() async {
        var initial = AppFeature.State()
        initial.captureDraft.text = "Existing text"
        initial.captureDraft.tags = "tag-a"
        initial.captureDraft.priority = .high
        initial.captureDraft.editingNoteID = UUID(uuidString: "44D1A620-53B0-49D7-9B60-2A1BA056EA28")!

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.sessionAddNoteTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft()
            $0.windowDestinations.insert(.captureWindow)
        }
    }

    @Test
    func captureSubmitTappedInEditModeUpdatesExistingNote() async {
        let active = makeActiveSession()
        let note = active.notes[0]
        let tracker = NoteMutationTracker()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.captureDraft.text = "Updated body"
        initial.captureDraft.tags = "alpha, beta"
        initial.captureDraft.priority = .medium
        initial.captureDraft.editingNoteID = note.id
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateNote = { noteID, _, _, _, _ in
            await tracker.recordUpdate(noteID: noteID)
            return nil
        }
        repository.createNote = { sessionID, _, _, _, _ in
            await tracker.recordCreate(sessionID: sessionID)
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { [] }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft()
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.noteDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse)

        let counts = await tracker.counts()
        #expect(counts.updated == [note.id])
        #expect(counts.created.isEmpty)
    }

    @Test
    func captureSubmitTappedWithoutEditModeCreatesNewNote() async {
        let active = makeActiveSession()
        let tracker = NoteMutationTracker()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.captureDraft.text = "New note body"
        initial.captureDraft.tags = "alpha, beta"
        initial.captureDraft.priority = .low
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateNote = { noteID, _, _, _, _ in
            await tracker.recordUpdate(noteID: noteID)
            return nil
        }
        repository.createNote = { sessionID, _, _, _, _ in
            await tracker.recordCreate(sessionID: sessionID)
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { [] }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft()
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.noteDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse)

        let counts = await tracker.counts()
        #expect(counts.created == [active.id])
        #expect(counts.updated.isEmpty)
    }

    @Test
    func endSessionTappedCreatesDraft() async {
        let active = makeActiveSession()
        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = [
            SessionCategoryRecord(
                id: FocusDefaults.focusCategoryID,
                name: FocusDefaults.focusCategoryName,
                normalizedName: FocusDefaults.focusCategoryName,
                colorHex: FocusDefaults.focusCategoryColorHex
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
    func exportAllWithoutSessionsShowsMessage() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.settingsExportAllTapped(URL(fileURLWithPath: "/tmp"))) {
            $0.settings.statusMessage = "No sessions available to export."
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
                    tags: active.notes[0].tags,
                    priority: active.notes[0].priority,
                    createdAt: active.notes[0].createdAt
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

actor NoteMutationTracker {
    private(set) var created: [UUID] = []
    private(set) var updated: [UUID] = []

    func recordCreate(sessionID: UUID) {
        created.append(sessionID)
    }

    func recordUpdate(noteID: UUID) {
        updated.append(noteID)
    }

    func counts() -> (created: [UUID], updated: [UUID]) {
        (created, updated)
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
