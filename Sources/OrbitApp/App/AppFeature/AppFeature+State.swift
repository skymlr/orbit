import CasePaths
import ComposableArchitecture
import Foundation

extension AppFeature {
    @CasePathable
    enum WindowDestination: Hashable, Sendable {
        case workspaceWindow
        case captureWindow
    }

    @ObservableState
    struct State: Equatable {
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

        var settings = SettingsState()
        var toast: Toast?

        var windowDestinations: Set<WindowDestination> = []
        var workspaceWindowFocusRequest = 0
        var captureWindowFocusRequest = 0
        var sessionBootstrapState: SessionBootstrapState = .idle
        var hasLaunched = false

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
