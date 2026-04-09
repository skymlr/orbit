import CasePaths
import ComposableArchitecture
import Foundation

extension AppFeature {
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)

        case onLaunch
        case appWillTerminate
        case inactivityTick

        case hotkeyTriggered(HotkeyKind)
        case registerHotkeys(HotkeySettings)

        case startSessionTapped
        case captureTapped
        case openWorkspaceTapped
        case openPreferencesTapped
        case endSessionTapped
        case exportAllButtonTapped
        case exportSessionButtonTapped(UUID)
        case exportDirectorySelected(URL)
        case exportDirectorySelectionCancelled

        case workspaceWindowClosed
        case captureWindowClosed
        case preferencesWindowClosed

        case captureDeleteTapped
        case captureSubmitTapped
        case sessionAddTaskTapped
        case sessionRenameTapped(String)
        case sessionTaskCategoryFilterToggled(UUID)
        case sessionTaskPriorityFilterToggled(NotePriority)
        case sessionTaskFiltersCleared
        case sessionTaskDeleteTapped(UUID)
        case sessionTaskEditTapped(UUID)
        case sessionTaskPriorityCycleTapped(UUID)
        case sessionTaskPrioritySetTapped(UUID, NotePriority)
        case sessionTaskCompletionToggled(UUID, Bool)
        case sessionTaskChecklistLineToggled(UUID, Int)

        case endSessionConfirmTapped(name: String)
        case endSessionCancelTapped
        case autoEndSession
        case sessionWindowBoundaryReached

        case settingsRefreshTapped
        case settingsCloudSyncToggled(Bool)
        case settingsCloudSyncRetryTapped
        case settingsResetHotkeysTapped
        case settingsSaveHotkeysTapped
        case settingsResetAppearanceTapped
        case settingsSaveAppearanceTapped
        case settingsAddCategoryTapped(String, String)
        case settingsRenameCategoryTapped(UUID, String, String)
        case settingsDeleteCategoryTapped(UUID)
        case settingsRenameSessionTapped(UUID, String)
        case settingsDeleteSessionTapped(UUID)
        case sharedExportPrepared([URL])
        case sharedExportFailed(String)
        case sharedExportDismissed
        case showToast(tone: State.Toast.Tone, message: String)
        case toastAutoDismissFired(UUID)
        case toastDismissTapped
        case retryBootstrapActiveSessionButtonTapped

        case bootstrapActiveSessionLoaded(FocusSessionRecord?)
        case bootstrapActiveSessionFailed(String)
        case cloudSyncMonitorUpdated(Bool, CloudSyncEngineState)
        case cloudSyncStartSucceeded
        case cloudSyncStartFailed(String)
        case cloudSyncFetchSucceeded
        case cloudSyncFetchFailed(String)
        case loadActiveSessionResponse(FocusSessionRecord?)
        case loadCategoriesResponse([SessionCategoryRecord])
        case settingsDataResponse([FocusSessionRecord], [SessionCategoryRecord])
    }
}
