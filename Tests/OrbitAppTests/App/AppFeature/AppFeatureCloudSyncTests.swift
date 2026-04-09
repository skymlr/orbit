import ComposableArchitecture
import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

@MainActor
struct AppFeatureCloudSyncTests {
    @Test
    func onLaunchWithSyncDisabledDoesNotStartCloudSync() async {
        let clock = TestClock()
        let syncTracker = CloudSyncTracker()
        let syncSettings = CloudSyncSettingsTracker(initialValue: false)

        var cloudSyncClient = CloudSyncClient.testValue
        cloudSyncClient.start = {
            syncTracker.recordStart()
        }
        cloudSyncClient.state = {
            syncTracker.state()
        }

        var initial = AppFeature.State()
        initial.platform.supportsCloudSync = true

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.cloudSyncClient = cloudSyncClient
            $0.cloudSyncSettingsClient = CloudSyncSettingsClient(
                load: { syncSettings.load() },
                save: { syncSettings.save($0) }
            )
            $0.continuousClock = clock
            $0.platformCapabilities = PlatformCapabilities(
                supportsGlobalHotkeys: false,
                supportsIdleMonitoring: false,
                supportsMenuBar: false,
                supportsPointerInteractions: false,
                usesShareExport: false,
                supportsCloudSync: true
            )
        }
        store.exhaustivity = .off

        await store.send(.onLaunch) {
            $0.appearance = .default
            $0.hasLaunched = true
            $0.isCloudSyncEnabled = false
            $0.platform = AppFeature.State.PlatformFeatures(
                supportsCloudSync: true
            )
            $0.sessionBootstrapState = .loading
            $0.settings.appearanceDraft = .default
            $0.settings.showsHotkeySettings = false
            $0.hotkeys = .default
            $0.settings.startShortcut = HotkeySettings.default.startShortcut
            $0.settings.captureShortcut = HotkeySettings.default.captureShortcut
            $0.settings.captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
            $0.syncStatus = .off
        }
        await store.skipReceivedActions(strict: false)
        await store.send(.appWillTerminate)

        let counts = syncTracker.counts()
        #expect(counts.starts == 0)
        #expect(store.state.syncStatus == .off)
        #expect(store.state.sessionBootstrapState == .loaded)
    }

    @Test
    func onLaunchWithSyncEnabledStartsCloudSyncBeforeLoadingData() async {
        let clock = TestClock()
        let syncTracker = CloudSyncTracker()
        let syncSettings = CloudSyncSettingsTracker(initialValue: true)
        let reconcileCounter = InvocationCounter()

        var repository = FocusRepository.testValue
        repository.reconcileSyncInvariants = {
            await reconcileCounter.record()
        }

        var cloudSyncClient = CloudSyncClient.testValue
        cloudSyncClient.start = {
            syncTracker.recordStart()
        }
        cloudSyncClient.state = {
            syncTracker.state()
        }

        var initial = AppFeature.State()
        initial.platform.supportsCloudSync = true

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.cloudSyncClient = cloudSyncClient
            $0.cloudSyncSettingsClient = CloudSyncSettingsClient(
                load: { syncSettings.load() },
                save: { syncSettings.save($0) }
            )
            $0.continuousClock = clock
            $0.focusRepository = repository
            $0.platformCapabilities = PlatformCapabilities(
                supportsGlobalHotkeys: false,
                supportsIdleMonitoring: false,
                supportsMenuBar: false,
                supportsPointerInteractions: false,
                usesShareExport: false,
                supportsCloudSync: true
            )
        }
        store.exhaustivity = .off

        await store.send(.onLaunch) {
            $0.appearance = .default
            $0.hasLaunched = true
            $0.isCloudSyncEnabled = true
            $0.platform = AppFeature.State.PlatformFeatures(
                supportsCloudSync: true
            )
            $0.sessionBootstrapState = .loading
            $0.settings.appearanceDraft = .default
            $0.settings.showsHotkeySettings = false
            $0.hotkeys = .default
            $0.settings.startShortcut = HotkeySettings.default.startShortcut
            $0.settings.captureShortcut = HotkeySettings.default.captureShortcut
            $0.settings.captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
            $0.syncStatus = .starting
        }
        await store.receive(\.cloudSyncStartSucceeded) {
            $0.syncStatus = .enabled
        }
        await store.skipReceivedActions(strict: false)
        await store.send(.appWillTerminate)

        let counts = syncTracker.counts()
        #expect(counts.starts == 1)
        #expect(await reconcileCounter.value() == 1)
        #expect(store.state.sessionBootstrapState == .loaded)
        #expect(store.state.isCloudSyncEnabled)
    }

    @Test
    func onLaunchWithSyncStartFailureKeepsToggleEnabledAndLoadsLocalData() async {
        let clock = TestClock()
        let toastID = UUID(uuidString: "7E1F63C3-7C9E-4CF9-A8E6-6313FB53AF6A")!
        let syncTracker = CloudSyncTracker()
        let syncSettings = CloudSyncSettingsTracker(initialValue: true)

        var cloudSyncClient = CloudSyncClient.testValue
        cloudSyncClient.start = {
            syncTracker.recordStart()
            throw AppFeatureTestError.failed
        }
        cloudSyncClient.state = {
            syncTracker.state()
        }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.cloudSyncClient = cloudSyncClient
            $0.cloudSyncSettingsClient = CloudSyncSettingsClient(
                load: { syncSettings.load() },
                save: { syncSettings.save($0) }
            )
            $0.continuousClock = clock
            $0.platformCapabilities = PlatformCapabilities(
                supportsGlobalHotkeys: false,
                supportsIdleMonitoring: false,
                supportsMenuBar: false,
                supportsPointerInteractions: false,
                usesShareExport: false,
                supportsCloudSync: true
            )
            $0.uuid = .constant(toastID)
        }
        store.exhaustivity = .off

        await store.send(.onLaunch) {
            $0.appearance = .default
            $0.hasLaunched = true
            $0.isCloudSyncEnabled = true
            $0.platform = AppFeature.State.PlatformFeatures(
                supportsCloudSync: true
            )
            $0.sessionBootstrapState = .loading
            $0.settings.appearanceDraft = .default
            $0.settings.showsHotkeySettings = false
            $0.hotkeys = .default
            $0.settings.startShortcut = HotkeySettings.default.startShortcut
            $0.settings.captureShortcut = HotkeySettings.default.captureShortcut
            $0.settings.captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
            $0.syncStatus = .starting
        }
        await store.skipReceivedActions(strict: false)

        let counts = syncTracker.counts()
        #expect(counts.starts == 1)
        #expect(store.state.isCloudSyncEnabled)
        #expect(store.state.sessionBootstrapState == .loaded)
        #expect(store.state.toast?.tone == .failure)

        guard case .retryNeeded = store.state.syncStatus else {
            Issue.record("Expected retryNeeded sync status after failed sync start.")
            return
        }

        await store.send(.appWillTerminate)
    }

    @Test
    func enablingSyncPersistsSettingStartsEngineAndRefreshesData() async {
        let syncTracker = CloudSyncTracker()
        let syncSettings = CloudSyncSettingsTracker(initialValue: false)
        let reconcileCounter = InvocationCounter()

        var repository = FocusRepository.testValue
        repository.reconcileSyncInvariants = {
            await reconcileCounter.record()
        }

        var cloudSyncClient = CloudSyncClient.testValue
        cloudSyncClient.start = {
            syncTracker.recordStart()
        }
        cloudSyncClient.state = {
            syncTracker.state()
        }

        var initial = AppFeature.State()
        initial.platform.supportsCloudSync = true

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.cloudSyncClient = cloudSyncClient
            $0.cloudSyncSettingsClient = CloudSyncSettingsClient(
                load: { syncSettings.load() },
                save: { syncSettings.save($0) }
            )
            $0.focusRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.settingsCloudSyncToggled(true)) {
            $0.isCloudSyncEnabled = true
            $0.syncStatus = .starting
        }
        await store.receive(\.cloudSyncStartSucceeded) {
            $0.syncStatus = .enabled
        }
        await store.skipReceivedActions(strict: false)

        let counts = syncTracker.counts()
        #expect(counts.starts == 1)
        #expect(syncSettings.values() == [true])
        #expect(await reconcileCounter.value() == 1)
        #expect(store.state.sessionBootstrapState == .loaded)
    }

    @Test
    func disablingSyncStopsEngineAndKeepsLocalState() async {
        let syncTracker = CloudSyncTracker()
        let syncSettings = CloudSyncSettingsTracker(initialValue: true)
        syncTracker.setState(
            CloudSyncEngineState(
                isRunning: true,
                isSynchronizing: false
            )
        )

        var cloudSyncClient = CloudSyncClient.testValue
        cloudSyncClient.stop = {
            syncTracker.recordStop()
        }
        cloudSyncClient.state = {
            syncTracker.state()
        }

        var initial = AppFeature.State()
        initial.activeSession = makeActiveSession(taskCategoryIDs: [appFeatureProjectACategoryID])
        initial.isCloudSyncEnabled = true
        initial.syncStatus = .enabled
        initial.platform.supportsCloudSync = true

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.cloudSyncClient = cloudSyncClient
            $0.cloudSyncSettingsClient = CloudSyncSettingsClient(
                load: { syncSettings.load() },
                save: { syncSettings.save($0) }
            )
        }

        await store.send(.settingsCloudSyncToggled(false)) {
            $0.isCloudSyncEnabled = false
            $0.syncStatus = .off
        }
        await store.skipInFlightEffects(strict: false)

        let counts = syncTracker.counts()
        #expect(counts.stops == 1)
        #expect(syncSettings.values() == [false])
        #expect(store.state.activeSession != nil)
    }

    @Test
    func retryUsesFetchWhenEngineIsAlreadyRunning() async {
        let syncTracker = CloudSyncTracker()
        syncTracker.setState(
            CloudSyncEngineState(
                isRunning: true,
                isSynchronizing: false
            )
        )
        let reconcileCounter = InvocationCounter()

        var repository = FocusRepository.testValue
        repository.reconcileSyncInvariants = {
            await reconcileCounter.record()
        }

        var cloudSyncClient = CloudSyncClient.testValue
        cloudSyncClient.fetchChanges = {
            syncTracker.recordFetch()
        }
        cloudSyncClient.state = {
            syncTracker.state()
        }

        var initial = AppFeature.State()
        initial.isCloudSyncEnabled = true
        initial.syncStatus = .retryNeeded("iCloud sync is paused or unavailable.")
        initial.platform.supportsCloudSync = true

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.cloudSyncClient = cloudSyncClient
            $0.focusRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.settingsCloudSyncRetryTapped) {
            $0.syncStatus = .syncing
        }
        await store.receive(\.cloudSyncFetchSucceeded) {
            $0.syncStatus = .enabled
        }
        await store.skipReceivedActions(strict: false)

        let counts = syncTracker.counts()
        #expect(counts.starts == 0)
        #expect(counts.fetches == 1)
        #expect(await reconcileCounter.value() == 1)
    }
}
