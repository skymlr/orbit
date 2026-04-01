import CasePaths
import ComposableArchitecture
import Foundation

extension AppFeature {
    @ObservableState
    struct State: Equatable {
        struct PlatformFeatures: Equatable, Sendable {
            var supportsGlobalHotkeys = false
            var supportsIdleMonitoring = false
            var supportsMenuBar = false
            var supportsPointerInteractions = false
            var usesShareExport = false
        }

        struct PresentationState: Equatable {
            struct DirectoryExportRequest: Equatable, Identifiable {
                var id: Int
                var sessionIDs: [UUID]
            }

            struct SharedExport: Equatable, Identifiable {
                var id: UUID
                var urls: [URL]
            }

            var isWorkspacePresented = false
            var workspacePresentationRequest = 0
            var isCapturePresented = false
            var capturePresentationRequest = 0
            var isPreferencesPresented = false
            var preferencesPresentationRequest = 0
            var pendingDirectoryExport: DirectoryExportRequest?
            var sharedExport: SharedExport?
        }

        enum SessionBootstrapState: Equatable {
            case idle
            case loading
            case failed(String)
            case loaded
        }

        struct CaptureDraft: Equatable {
            var markdown = ""
            var priority: NotePriority = .none
            var selectedCategoryIDs: [UUID] = []
            var editingTaskID: UUID?
        }

        struct EndSessionDraft: Equatable, Identifiable {
            var id = UUID()
            var name = ""
        }

        struct TaskDraft: Equatable, Identifiable {
            var id: UUID
            var categories: [NoteCategoryRecord]
            var markdown: String
            var priority: NotePriority
            var completedAt: Date?
            var carriedFromTaskID: UUID?
            var carriedFromSessionName: String?
            var createdAt: Date
        }

        struct Toast: Equatable, Identifiable {
            enum Tone: Equatable {
                case success
                case failure
            }

            var id: UUID
            var tone: Tone
            var message: String
        }

        struct SettingsState: Equatable {
            var sessions: [FocusSessionRecord] = []
            var categories: [SessionCategoryRecord] = []
            var showsHotkeySettings = false
            var startShortcut = HotkeySettings.default.startShortcut
            var captureShortcut = HotkeySettings.default.captureShortcut
            var captureNextPriorityShortcut = HotkeySettings.default.captureNextPriorityShortcut
            var appearanceDraft = AppearanceSettings.default
        }

        var activeSession: FocusSessionRecord?
        var taskDrafts: IdentifiedArrayOf<TaskDraft> = []

        var categories: [SessionCategoryRecord] = []
        var hotkeys: HotkeySettings = .default
        var appearance: AppearanceSettings = .default

        var captureDraft = CaptureDraft()
        var endSessionDraft: EndSessionDraft?

        var selectedTaskCategoryFilterIDs: Set<UUID> = []
        var selectedTaskPriorityFilters: Set<NotePriority> = []

        var platform = PlatformFeatures()
        var presentation = PresentationState()
        var settings = SettingsState()
        var toast: Toast?

        var sessionBootstrapState: SessionBootstrapState = .idle
        var hasLaunched = false

        var isLaunching: Bool {
            !hasLaunched || sessionBootstrapState == .loading
        }

        var filteredTaskDrafts: [TaskDraft] {
            taskDrafts.filter { draft in
                let categoryMatch: Bool
                if selectedTaskCategoryFilterIDs.isEmpty {
                    categoryMatch = true
                } else {
                    categoryMatch = draft.categories.contains(where: { selectedTaskCategoryFilterIDs.contains($0.id) })
                }

                let priorityMatch: Bool
                if selectedTaskPriorityFilters.isEmpty {
                    priorityMatch = true
                } else {
                    priorityMatch = selectedTaskPriorityFilters.contains(draft.priority)
                }

                return categoryMatch && priorityMatch
            }
        }
    }
}

extension AppFeature.State.PlatformFeatures {
    init(_ capabilities: PlatformCapabilities) {
        self.init(
            supportsGlobalHotkeys: capabilities.supportsGlobalHotkeys,
            supportsIdleMonitoring: capabilities.supportsIdleMonitoring,
            supportsMenuBar: capabilities.supportsMenuBar,
            supportsPointerInteractions: capabilities.supportsPointerInteractions,
            usesShareExport: capabilities.usesShareExport
        )
    }
}
