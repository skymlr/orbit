import ComposableArchitecture
import SwiftUI

struct SessionTaskFilterBar: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @State private var isTaskFilterPopoverPresented = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            filterToggleButton

            if activeFilterCount != 0 {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        activeFilterChips
                    }
                }
                .scrollIndicators(.hidden)
            }

            Spacer(minLength: 0)
        }
    }

    private var filterToggleButton: some View {
        Button {
            isTaskFilterPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("Filters")
                    .lineLimit(1)

                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .orbitFont(.caption2, monospacedDigits: true)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.15))
                        )
                }
            }
            .orbitFont(.caption, weight: .semibold)
        }
        .buttonStyle(.orbitQuiet)
        .popover(isPresented: $isTaskFilterPopoverPresented, arrowEdge: .bottom) {
            filterPickerPopover
        }
        .accessibilityLabel("Filters")
        .accessibilityValue("\(activeFilterCount) active filters")
        .accessibilityHint("Open filter picker")
        .keyboardShortcut("f")
        .help("Filters (\(activeFilterCount) active)")
    }

    @ViewBuilder
    private var activeFilterChips: some View {
        ForEach(Self.priorityFilterOrder.filter(isPrioritySelected(_:)), id: \.self) { priority in
            activeFilterChip(
                title: "Priority: \(priority.title)",
                tint: priorityFilterTint(for: priority),
                icon: priorityFilterIcon(for: priority),
                accessibilityLabel: "Priority filter \(priority.title), active"
            ) {
                store.send(.sessionTaskPriorityFilterToggled(priority))
            }
        }

        ForEach(selectedFilteredCategories) { category in
            activeFilterChip(
                title: "Category: \(category.name)",
                tint: Color(orbitHex: category.colorHex),
                icon: "tag.fill",
                accessibilityLabel: "Category filter \(category.name), active"
            ) {
                store.send(.sessionTaskCategoryFilterToggled(category.id))
            }
        }
    }

    private var filterPickerPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .orbitFont(.headline)

                Spacer()

                if activeFilterCount > 0 {
                    Button("Clear all") {
                        clearAllFilters()
                    }
                    .buttonStyle(.orbitQuiet)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Priorities")
                    .orbitFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Self.priorityFilterOrder, id: \.self) { priority in
                            priorityFilterChip(
                                title: priority.title,
                                count: countForPriority(priority),
                                isSelected: isPrioritySelected(priority),
                                tint: priorityFilterTint(for: priority),
                                icon: priorityFilterIcon(for: priority)
                            ) {
                                store.send(.sessionTaskPriorityFilterToggled(priority))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Categories")
                    .orbitFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(categoriesWithTasks) { category in
                            filterChip(
                                title: category.name,
                                count: countForCategory(category.id),
                                isSelected: isCategorySelected(category.id),
                                tint: Color(orbitHex: category.colorHex)
                            ) {
                                store.send(.sessionTaskCategoryFilterToggled(category.id))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(14)
        .frame(width: 430)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .orbitOnExitCommand {
            isTaskFilterPopoverPresented = false
        }
    }

    private func activeFilterChip(
        title: String,
        tint: Color,
        icon: String,
        accessibilityLabel: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .orbitFont(.caption2, weight: .bold)

                Text(title)
                    .lineLimit(1)

                Image(systemName: "xmark.circle.fill")
                    .orbitFont(.caption2, weight: .bold)
            }
            .orbitFont(.caption, weight: .semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.28))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.95), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Remove filter")
    }

    private func isCategorySelected(_ categoryID: UUID) -> Bool {
        store.selectedTaskCategoryFilterIDs.contains(categoryID)
    }

    private func countForCategory(_ categoryID: UUID) -> Int {
        store.taskDrafts.filter { draft in
            draft.categories.contains(where: { $0.id == categoryID })
        }
        .count
    }

    private func countForPriority(_ priority: NotePriority) -> Int {
        store.taskDrafts.filter { draft in
            draft.priority == priority
        }
        .count
    }

    private var categoriesWithTasks: [SessionCategoryRecord] {
        store.categories.filter { countForCategory($0.id) > 0 }
    }

    private func isPrioritySelected(_ priority: NotePriority) -> Bool {
        store.selectedTaskPriorityFilters.contains(priority)
    }

    private var selectedFilteredCategories: [SessionCategoryRecord] {
        store.categories.filter { store.selectedTaskCategoryFilterIDs.contains($0.id) }
    }

    private func filterChip(
        title: String,
        count: Int,
        isSelected: Bool,
        tint: Color = .secondary,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            OrbitCategoryChip(
                title: title,
                tint: tint,
                isSelected: isSelected,
                count: count
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Category filter \(title)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Shows \(count) tasks")
    }

    private func priorityFilterChip(
        title: String,
        count: Int,
        isSelected: Bool,
        tint: Color,
        icon: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .orbitFont(.caption2, weight: .bold)

                Text(title)
                    .lineLimit(1)

                Text("\(count)")
                    .orbitFont(.caption2, monospacedDigits: true)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.15))
                    )
            }
            .orbitFont(.caption, weight: .semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? tint.opacity(0.28) : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint.opacity(0.95) : Color.white.opacity(0.22), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Priority filter \(title)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Shows \(count) tasks")
    }

    private func priorityFilterTint(for priority: NotePriority) -> Color {
        switch priority {
        case .none:
            return Color(red: 0.62, green: 0.70, blue: 0.84)
        case .low:
            return Color(red: 0.08, green: 0.86, blue: 0.78)
        case .medium:
            return Color(red: 1.00, green: 0.74, blue: 0.18)
        case .high:
            return Color(red: 1.00, green: 0.27, blue: 0.54)
        }
    }

    private func priorityFilterIcon(for priority: NotePriority) -> String {
        switch priority {
        case .none:
            return "minus.circle"
        case .low:
            return "arrow.down.circle.fill"
        case .medium:
            return "equal.circle.fill"
        case .high:
            return "exclamationmark.circle.fill"
        }
    }

    private var activeFilterCount: Int {
        store.selectedTaskCategoryFilterIDs.count + store.selectedTaskPriorityFilters.count
    }

    private func clearAllFilters() {
        store.send(.sessionTaskFiltersCleared)
    }

    private static let priorityFilterOrder: [NotePriority] = [
        .high,
        .medium,
        .low,
        .none,
    ]
}
