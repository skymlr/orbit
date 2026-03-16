import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct AppFeature {
    enum CancelID {
        case inactivityMonitor
        case sessionWindowMonitor
        case hotkeyRegistration
        case toastAutoDismiss
    }

    @Dependency(\.continuousClock) var continuousClock
    @Dependency(\.appearanceSettingsClient) var appearanceSettingsClient
    @Dependency(\.date.now) var now
    @Dependency(\.focusRepository) var focusRepository
    @Dependency(\.hotkeyManager) var hotkeyManager
    @Dependency(\.hotkeySettingsClient) var hotkeySettingsClient
    @Dependency(\.inactivityClient) var inactivityClient
    @Dependency(\.markdownExportClient) var markdownExportClient
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .appWillTerminate,
                    .bootstrapActiveSessionFailed,
                    .bootstrapActiveSessionLoaded,
                    .captureWindowClosed,
                    .hotkeyTriggered,
                    .inactivityTick,
                    .loadActiveSessionResponse,
                    .loadCategoriesResponse,
                    .onLaunch,
                    .registerHotkeys,
                    .retryBootstrapActiveSessionButtonTapped,
                    .settingsDataResponse,
                    .workspaceWindowClosed:
                return reduceLifecycle(into: &state, action: action)

            case .autoEndSession,
                    .captureSubmitTapped,
                    .captureTapped,
                    .endSessionCancelTapped,
                    .endSessionConfirmTapped,
                    .endSessionTapped,
                    .openWorkspaceTapped,
                    .sessionAddTaskTapped,
                    .sessionRenameTapped,
                    .sessionTaskCategoryFilterToggled,
                    .sessionTaskChecklistLineToggled,
                    .sessionTaskCompletionToggled,
                    .sessionTaskDeleteTapped,
                    .sessionTaskEditTapped,
                    .sessionTaskFiltersCleared,
                    .sessionTaskPriorityCycleTapped,
                    .sessionTaskPriorityFilterToggled,
                    .sessionTaskPrioritySetTapped,
                    .sessionWindowBoundaryReached,
                    .startSessionTapped:
                return reduceSession(into: &state, action: action)

            case .settingsAddCategoryTapped,
                    .settingsDeleteCategoryTapped,
                    .settingsDeleteSessionTapped,
                    .settingsExportAllTapped,
                    .settingsExportSessionTapped,
                    .settingsRefreshTapped,
                    .settingsResetAppearanceTapped,
                    .settingsRenameCategoryTapped,
                    .settingsRenameSessionTapped,
                    .settingsResetHotkeysTapped,
                    .settingsSaveAppearanceTapped,
                    .settingsSaveHotkeysTapped,
                    .showToast,
                    .toastAutoDismissFired,
                    .toastDismissTapped:
                return reduceSettings(into: &state, action: action)
            }
        }
    }
}
