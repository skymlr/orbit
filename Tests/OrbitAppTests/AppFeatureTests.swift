import ComposableArchitecture
import Foundation
import Testing
@testable import OrbitApp

@MainActor
struct AppFeatureTests {
    @Test
    func sessionNoteEditTappedPrefillsCaptureAndOpensWindow() async {
        let active = makeActiveSession(noteCategoryIDs: [projectACategoryID, projectBCategoryID])
        let note = active.notes[0]

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.noteDrafts = [
            AppFeature.State.NoteDraft(
                id: note.id,
                categories: note.categories,
                text: note.text,
                priority: note.priority,
                createdAt: note.createdAt
            )
        ]
        initial.categories = sampleCategories

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.sessionNoteEditTapped(note.id)) {
            $0.captureDraft.text = note.text
            $0.captureDraft.priority = note.priority
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID, projectBCategoryID]
            $0.captureDraft.editingNoteID = note.id
            $0.windowDestinations.insert(.captureWindow)
        }
    }

    @Test
    func sessionAddNoteTappedResetsEditContext() async {
        var initial = AppFeature.State()
        initial.categories = sampleCategories
        initial.captureDraft.text = "Existing text"
        initial.captureDraft.priority = .high
        initial.captureDraft.selectedCategoryIDs = [projectBCategoryID]
        initial.captureDraft.editingNoteID = UUID(uuidString: "44D1A620-53B0-49D7-9B60-2A1BA056EA28")!

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.sessionAddNoteTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [projectBCategoryID]
            )
            $0.windowDestinations.insert(.captureWindow)
        }
    }

    @Test
    func captureSubmitTappedInEditModeUpdatesExistingNote() async {
        let active = makeActiveSession(noteCategoryIDs: [projectACategoryID])
        let note = active.notes[0]
        let tracker = NoteMutationTracker()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.text = "Updated body"
        initial.captureDraft.priority = .medium
        initial.captureDraft.selectedCategoryIDs = [projectBCategoryID, projectACategoryID]
        initial.captureDraft.editingNoteID = note.id
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateNote = { noteID, _, _, categoryIDs, _ in
            await tracker.recordUpdate(noteID: noteID, categoryIDs: categoryIDs)
            return nil
        }
        repository.createNote = { sessionID, _, _, categoryIDs, _ in
            await tracker.recordCreate(sessionID: sessionID, categoryIDs: categoryIDs)
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [projectBCategoryID, projectACategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.noteDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [FocusDefaults.uncategorizedCategoryID]
            )
            $0.selectedNoteCategoryFilter = .all
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        let counts = await tracker.counts()
        #expect(counts.updated == [note.id])
        #expect(counts.updatedCategories == [[projectBCategoryID, projectACategoryID]])
        #expect(counts.created.isEmpty)
    }

    @Test
    func captureSubmitTappedWithoutEditModeCreatesNewNote() async {
        let active = makeActiveSession(noteCategoryIDs: [projectACategoryID])
        let tracker = NoteMutationTracker()

        var initial = AppFeature.State()
        initial.activeSession = active
        initial.categories = sampleCategories
        initial.captureDraft.text = "New note body"
        initial.captureDraft.priority = .low
        initial.captureDraft.selectedCategoryIDs = [projectACategoryID, projectBCategoryID]
        initial.windowDestinations.insert(.captureWindow)

        var repository = FocusRepository.testValue
        repository.updateNote = { noteID, _, _, categoryIDs, _ in
            await tracker.recordUpdate(noteID: noteID, categoryIDs: categoryIDs)
            return nil
        }
        repository.createNote = { sessionID, _, _, categoryIDs, _ in
            await tracker.recordCreate(sessionID: sessionID, categoryIDs: categoryIDs)
            return nil
        }
        repository.loadActiveSession = { nil }
        repository.listSessions = { [] }
        repository.listCategories = { sampleCategories }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.focusRepository = repository
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }

        await store.send(.captureSubmitTapped) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [projectACategoryID, projectBCategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
        await store.receive(\.loadActiveSessionResponse) {
            $0.activeSession = nil
            $0.noteDrafts = []
            $0.endSessionDraft = nil
            $0.windowDestinations = []
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [FocusDefaults.uncategorizedCategoryID]
            )
            $0.selectedNoteCategoryFilter = .all
        }
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.settingsDataResponse) {
            $0.settings.categories = sampleCategories
            $0.categories = sampleCategories
        }

        let counts = await tracker.counts()
        #expect(counts.created == [active.id])
        #expect(counts.createdCategories == [[projectACategoryID, projectBCategoryID]])
        #expect(counts.updated.isEmpty)
    }

    @Test
    func captureWindowClosedResetsDraftAndWindow() async {
        var initial = AppFeature.State()
        initial.captureDraft.text = "Investigate perf regression"
        initial.captureDraft.priority = .high
        initial.captureDraft.selectedCategoryIDs = [projectBCategoryID]
        initial.windowDestinations.insert(.captureWindow)

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.captureWindowClosed) {
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [FocusDefaults.uncategorizedCategoryID]
            )
            $0.windowDestinations.remove(.captureWindow)
        }
    }

    @Test
    func loadActiveSessionDefaultsCaptureCategoryToMostRecentNoteCategories() async {
        let olderNote = FocusNoteRecord(
            id: UUID(uuidString: "D10501A3-EB95-4B5D-9F97-C8E35E5BCA61")!,
            sessionID: UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!,
            categories: noteCategories([projectACategoryID]),
            text: "Older",
            priority: .none,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let newerNote = FocusNoteRecord(
            id: UUID(uuidString: "DFBA97DE-5139-49DB-9D03-6F62A2A6A955")!,
            sessionID: olderNote.sessionID,
            categories: noteCategories([projectBCategoryID, projectACategoryID]),
            text: "Newer",
            priority: .none,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let session = FocusSessionRecord(
            id: olderNote.sessionID,
            name: "Two notes",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: nil,
            endedReason: nil,
            notes: [olderNote, newerNote]
        )

        var initial = AppFeature.State()
        initial.categories = sampleCategories

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.loadActiveSessionResponse(session)) {
            $0.activeSession = session
            $0.noteDrafts = [
                AppFeature.State.NoteDraft(
                    id: newerNote.id,
                    categories: newerNote.categories,
                    text: newerNote.text,
                    priority: newerNote.priority,
                    createdAt: newerNote.createdAt
                ),
                AppFeature.State.NoteDraft(
                    id: olderNote.id,
                    categories: olderNote.categories,
                    text: olderNote.text,
                    priority: olderNote.priority,
                    createdAt: olderNote.createdAt
                )
            ]
            $0.captureDraft.selectedCategoryIDs = [projectBCategoryID, projectACategoryID]
        }

        await store.send(.loadActiveSessionResponse(nil)) {
            $0.activeSession = nil
            $0.noteDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [FocusDefaults.uncategorizedCategoryID]
            )
            $0.selectedNoteCategoryFilter = .all
        }
    }

    @Test
    func sessionNoteCategoryFilterChangedUpdatesState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.sessionNoteCategoryFilterChangedTapped(.category(projectACategoryID))) {
            $0.selectedNoteCategoryFilter = .category(projectACategoryID)
        }

        await store.send(.sessionNoteCategoryFilterChangedTapped(.all)) {
            $0.selectedNoteCategoryFilter = .all
        }
    }

    @Test
    func loadActiveSessionResetsCategoryFilterWhenNoNotesRemainInSelectedCategory() async {
        let active = makeActiveSession(noteCategoryIDs: [projectACategoryID])

        var initial = AppFeature.State()
        initial.categories = sampleCategories
        initial.selectedNoteCategoryFilter = .category(projectBCategoryID)

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.loadActiveSessionResponse(active)) {
            $0.activeSession = active
            $0.noteDrafts = [
                AppFeature.State.NoteDraft(
                    id: active.notes[0].id,
                    categories: active.notes[0].categories,
                    text: active.notes[0].text,
                    priority: active.notes[0].priority,
                    createdAt: active.notes[0].createdAt
                )
            ]
            $0.captureDraft.selectedCategoryIDs = [projectACategoryID]
            $0.selectedNoteCategoryFilter = .all
        }

        await store.send(.loadActiveSessionResponse(nil)) {
            $0.activeSession = nil
            $0.noteDrafts = []
            $0.endSessionDraft = nil
            $0.captureDraft = AppFeature.State.CaptureDraft(
                selectedCategoryIDs: [FocusDefaults.uncategorizedCategoryID]
            )
            $0.selectedNoteCategoryFilter = .all
        }
    }
}

actor NoteMutationTracker {
    private(set) var created: [UUID] = []
    private(set) var createdCategories: [[UUID]] = []
    private(set) var updated: [UUID] = []
    private(set) var updatedCategories: [[UUID]] = []

    func recordCreate(sessionID: UUID, categoryIDs: [UUID]) {
        created.append(sessionID)
        createdCategories.append(categoryIDs)
    }

    func recordUpdate(noteID: UUID, categoryIDs: [UUID]) {
        updated.append(noteID)
        updatedCategories.append(categoryIDs)
    }

    func counts() -> (
        created: [UUID],
        createdCategories: [[UUID]],
        updated: [UUID],
        updatedCategories: [[UUID]]
    ) {
        (created, createdCategories, updated, updatedCategories)
    }
}

private let projectACategoryID = UUID(uuidString: "3261E8B5-4302-4D32-9FDF-F5D4AB4AF4D9")!
private let projectBCategoryID = UUID(uuidString: "A4E2AC92-241D-40A1-AB2B-33804D08EE18")!

private var sampleCategories: [SessionCategoryRecord] {
    [
        SessionCategoryRecord(
            id: projectACategoryID,
            name: "project-a",
            normalizedName: "project-a",
            colorHex: "#58B5FF"
        ),
        SessionCategoryRecord(
            id: projectBCategoryID,
            name: "project-b",
            normalizedName: "project-b",
            colorHex: "#7ED957"
        ),
        SessionCategoryRecord(
            id: FocusDefaults.uncategorizedCategoryID,
            name: FocusDefaults.uncategorizedCategoryName,
            normalizedName: FocusDefaults.uncategorizedCategoryName,
            colorHex: FocusDefaults.uncategorizedCategoryColorHex
        ),
    ]
}

private func noteCategories(_ ids: [UUID]) -> [NoteCategoryRecord] {
    let byID = Dictionary(uniqueKeysWithValues: sampleCategories.map { ($0.id, $0) })
    return ids.compactMap { id in
        guard let category = byID[id] else { return nil }
        return NoteCategoryRecord(id: category.id, name: category.name, colorHex: category.colorHex)
    }
}

private func makeActiveSession(
    noteCategoryIDs: [UUID] = [FocusDefaults.uncategorizedCategoryID]
) -> FocusSessionRecord {
    let note = FocusNoteRecord(
        id: UUID(uuidString: "A6E2C2D2-53AF-4D10-ACE2-761B700A1DB1")!,
        sessionID: UUID(uuidString: "9D8A53C2-1EE7-4E04-AC93-8E09B6F03D40")!,
        categories: noteCategories(noteCategoryIDs),
        text: "Ship Orbit session window",
        priority: .high,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    return FocusSessionRecord(
        id: note.sessionID,
        name: "2026-02-26 10:30",
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        endedAt: nil,
        endedReason: nil,
        notes: [note]
    )
}
