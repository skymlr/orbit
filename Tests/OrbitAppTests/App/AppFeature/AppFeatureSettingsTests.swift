import ComposableArchitecture
import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

@MainActor
struct AppFeatureSettingsTests {
    @Test
    func onLaunchLoadsPersistedAppearanceIntoAppliedAndDraftState() async {
        let persistedAppearance = AppearanceSettings(
            font: .sourceSerif4,
            background: .glass
        )

        var appearanceClient = AppearanceSettingsClient.testValue
        appearanceClient.load = { persistedAppearance }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appearanceSettingsClient = appearanceClient
        }

        await store.send(.onLaunch) {
            $0.appearance = persistedAppearance
            $0.hasLaunched = true
            $0.sessionBootstrapState = .loading
            $0.settings.appearanceDraft = persistedAppearance
            $0.hotkeys = .default
            $0.settings.startShortcut = HotkeySettings.default.startShortcut
            $0.settings.captureShortcut = HotkeySettings.default.captureShortcut
            $0.settings.captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
        }
        await store.receive(\.registerHotkeys)
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.bootstrapActiveSessionLoaded) {
            $0.sessionBootstrapState = .loaded
        }
        await store.receive(\.loadActiveSessionResponse)
        await store.receive(\.loadCategoriesResponse)
        await store.receive(\.settingsDataResponse)
        await store.send(.appWillTerminate)
    }

    @Test
    func settingsExportAllTappedWithNoCompletedSessionsShowsFailureToast() async {
        let toastID = UUID(uuidString: "58D6FB1D-0A12-4D3E-B12A-17448DA0EED6")!
        let clock = TestClock()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .constant(toastID)
        }

        await store.send(.settingsExportAllTapped(URL(fileURLWithPath: "/tmp/orbit-export")))
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .failure,
                message: "No completed sessions to export"
            )
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }
    }

    @Test
    func settingsExportAllTappedExportsCompletedSessionsShowsSuccessToast() async {
        let toastID = UUID(uuidString: "C0B5036A-9E61-4F34-A57F-2B8264B8C54A")!
        let exportDirectory = URL(fileURLWithPath: "/tmp/orbit-export")
        let clock = TestClock()
        let tracker = MarkdownExportTracker()

        let completedSessionA = FocusSessionRecord(
            id: UUID(uuidString: "BDEEC696-EC3A-4DB6-8FB0-C3BAABAB0D44")!,
            name: "Morning Session",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_400),
            endedReason: .manual,
            tasks: []
        )
        let completedSessionB = FocusSessionRecord(
            id: UUID(uuidString: "7AFA2104-69F6-413B-8DF3-98A8053CF922")!,
            name: "Afternoon Session",
            startedAt: Date(timeIntervalSince1970: 1_700_010_000),
            endedAt: Date(timeIntervalSince1970: 1_700_010_300),
            endedReason: .manual,
            tasks: []
        )

        var initial = AppFeature.State()
        initial.settings.sessions = [
            completedSessionA,
            makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID]),
            completedSessionB,
        ]

        var exportClient = MarkdownExportClient.testValue
        exportClient.export = { sessionIDs, directoryURL in
            await tracker.record(sessionIDs: sessionIDs, directoryURL: directoryURL)
            return [
                directoryURL.appendingPathComponent("morning-session.md"),
                directoryURL.appendingPathComponent("afternoon-session.md"),
            ]
        }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.markdownExportClient = exportClient
            $0.uuid = .constant(toastID)
        }

        await store.send(.settingsExportAllTapped(exportDirectory))
        await store.receive(\.settingsRefreshTapped)
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .success,
                message: "Exported 2 session file(s)."
            )
        }
        await store.receive(\.settingsDataResponse) {
            $0.settings.sessions = []
            $0.settings.categories = []
            $0.categories = []
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }

        let export = await tracker.export()
        #expect(export?.sessionIDs == [completedSessionA.id, completedSessionB.id])
        #expect(export?.directoryURL == exportDirectory)
    }

    @Test
    func settingsAddCategoryTappedWithDuplicateOrInvalidValueShowsFailureToast() async {
        let toastID = UUID(uuidString: "1A91951B-35A7-43A8-B4DC-4EA2463569FA")!
        let clock = TestClock()

        var repository = FocusRepository.testValue
        repository.addCategory = { _, _ in nil }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.focusRepository = repository
            $0.uuid = .constant(toastID)
        }

        await store.send(.settingsAddCategoryTapped("project-a", "#58B5FF"))
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .failure,
                message: "Category already exists or name is invalid"
            )
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }
    }

    @Test
    func settingsSaveAppearanceTappedPersistsAppliedAppearanceAndShowsToast() async {
        let toastID = UUID(uuidString: "AC0A8360-F5B2-4D47-A2C8-47AB319538A4")!
        let clock = TestClock()
        let tracker = AppearanceSettingsTracker()
        let customAppearance = AppearanceSettings(
            font: .geist,
            background: .purple
        )

        var initial = AppFeature.State()
        initial.settings.appearanceDraft = customAppearance

        var appearanceClient = AppearanceSettingsClient.testValue
        appearanceClient.save = { settings in
            tracker.record(settings)
        }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.appearanceSettingsClient = appearanceClient
            $0.continuousClock = clock
            $0.uuid = .constant(toastID)
        }

        await store.send(.settingsSaveAppearanceTapped) {
            $0.appearance = customAppearance
        }
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .success,
                message: "Appearance saved"
            )
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }

        #expect(tracker.values() == [customAppearance])
    }

    @Test
    func settingsResetAppearanceTappedRestoresDefaultsPersistsAndShowsToast() async {
        let toastID = UUID(uuidString: "8C3B93B8-F828-46E1-B999-2FF5A3E1E0DD")!
        let clock = TestClock()
        let tracker = AppearanceSettingsTracker()

        var initial = AppFeature.State()
        initial.appearance = AppearanceSettings(
            font: .geist,
            background: .glass
        )
        initial.settings.appearanceDraft = AppearanceSettings(
            font: .sourceSerif4,
            background: .purple
        )

        var appearanceClient = AppearanceSettingsClient.testValue
        appearanceClient.save = { settings in
            tracker.record(settings)
        }

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.appearanceSettingsClient = appearanceClient
            $0.continuousClock = clock
            $0.uuid = .constant(toastID)
        }

        await store.send(.settingsResetAppearanceTapped) {
            $0.appearance = .default
            $0.settings.appearanceDraft = .default
        }
        await store.receive(\.showToast) {
            $0.toast = AppFeature.State.Toast(
                id: toastID,
                tone: .success,
                message: "Appearance reset to defaults"
            )
        }
        await store.send(.toastDismissTapped) {
            $0.toast = nil
        }

        #expect(tracker.values() == [.default])
    }
}
