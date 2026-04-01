import Foundation

struct LiveTaskSearchResult: Equatable {
    let session: FocusSessionRecord
    let tasks: [AppFeature.State.TaskDraft]
    let isSessionNameMatch: Bool
}

enum SessionTaskDraftSearchSupport {
    static func filteredTasks(
        from taskDrafts: [AppFeature.State.TaskDraft],
        selectedCategoryFilterIDs: Set<UUID>,
        selectedPriorityFilters: Set<NotePriority>,
        searchText: String
    ) -> [AppFeature.State.TaskDraft] {
        let tasks = taskDrafts.filter {
            matchesSelectedFilters(
                $0,
                selectedCategoryFilterIDs: selectedCategoryFilterIDs,
                selectedPriorityFilters: selectedPriorityFilters
            )
        }

        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
            return sortedTasks(tasks)
        }

        return sortedTasks(tasks.filter { matchesSearch($0, query: trimmedSearchText) })
    }

    static func liveSearchResult(
        activeSession: FocusSessionRecord?,
        taskDrafts: [AppFeature.State.TaskDraft],
        query: String,
        filter: HistoryTaskFilter
    ) -> LiveTaskSearchResult? {
        guard let activeSession else { return nil }

        let filteredTasks = taskDrafts.filter { matchesHistoryFilter($0, filter: filter) }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return LiveTaskSearchResult(
                session: activeSession,
                tasks: sortedTasks(filteredTasks),
                isSessionNameMatch: false
            )
        }

        let isSessionNameMatch = activeSession.name.localizedCaseInsensitiveContains(trimmedQuery)
        let matchingTasks = filteredTasks.filter { task in
            isSessionNameMatch || matchesSearch(task, query: trimmedQuery)
        }

        return LiveTaskSearchResult(
            session: activeSession,
            tasks: sortedTasks(matchingTasks),
            isSessionNameMatch: isSessionNameMatch
        )
    }

    static func matchesSelectedFilters(
        _ draft: AppFeature.State.TaskDraft,
        selectedCategoryFilterIDs: Set<UUID>,
        selectedPriorityFilters: Set<NotePriority>
    ) -> Bool {
        let categoryMatch: Bool
        if selectedCategoryFilterIDs.isEmpty {
            categoryMatch = true
        } else {
            categoryMatch = draft.categories.contains(where: { selectedCategoryFilterIDs.contains($0.id) })
        }

        let priorityMatch: Bool
        if selectedPriorityFilters.isEmpty {
            priorityMatch = true
        } else {
            priorityMatch = selectedPriorityFilters.contains(draft.priority)
        }

        return categoryMatch && priorityMatch
    }

    static func matchesHistoryFilter(
        _ draft: AppFeature.State.TaskDraft,
        filter: HistoryTaskFilter
    ) -> Bool {
        switch filter {
        case .completed:
            return draft.isCompleted
        case .all:
            return true
        case .open:
            return !draft.isCompleted
        case .createdInSession:
            return draft.wasCreatedInSession
        }
    }

    static func matchesSearch(
        _ draft: AppFeature.State.TaskDraft,
        query: String
    ) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }
        return draft.markdown.localizedCaseInsensitiveContains(trimmedQuery)
    }

    static func sortedTasks(
        _ tasks: [AppFeature.State.TaskDraft]
    ) -> [AppFeature.State.TaskDraft] {
        tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }
            if lhs.priority != rhs.priority {
                return priorityRank(lhs.priority) > priorityRank(rhs.priority)
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private static func priorityRank(_ priority: NotePriority) -> Int {
        switch priority {
        case .none:
            return 0
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }
}

extension AppFeature.State.TaskDraft {
    var isCompleted: Bool {
        completedAt != nil
    }

    var wasCreatedInSession: Bool {
        carriedFromTaskID == nil
    }
}
