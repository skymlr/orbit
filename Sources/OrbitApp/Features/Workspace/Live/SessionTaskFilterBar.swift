import ComposableArchitecture
import Flow
import SwiftUI

struct SessionTaskFilterToolbarButton: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.orbitAdaptiveLayout) private var layout
    @Binding var isTaskFilterPopoverPresented: Bool

    var body: some View {
        pickerButton
    }

    private var pickerButton: some View {
        Button {
            isTaskFilterPopoverPresented.toggle()
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .badge(activeFilterBadge)
        .accessibilityLabel("Filters")
        .accessibilityValue("\(activeFilterCount) active filters")
        .accessibilityHint("Open filter picker")
        .keyboardShortcut("f")
        .help(activeFilterCount == 0 ? "Filters" : "Filters (\(activeFilterCount) active)")
        .modifier(
            FilterPickerPresentationModifier(
                layout: layout,
                store: store,
                isPresented: $isTaskFilterPopoverPresented
            )
        )
    }

    private var activeFilterCount: Int {
        SessionTaskFilterSupport.activeFilterCount(in: store)
    }

    private var activeFilterBadge: String? {
        activeFilterCount == 0 ? nil : "\(activeFilterCount)"
    }
}

struct SessionTaskFilterBar: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.orbitAdaptiveLayout) private var layout

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    activeFilterChips
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, layout.isCompact ? 12 : 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
#if os(iOS)
        .modifier(CompactFilterBarCardModifier(isCompact: layout.isCompact))
#endif
    }

    @ViewBuilder
    private var activeFilterChips: some View {
        ForEach(selectedPriorities, id: \.self) { priority in
            activeFilterChip(
                title: priority.title,
                tint: SessionTaskFilterSupport.priorityFilterTint(for: priority),
                icon: SessionTaskFilterSupport.priorityFilterIcon(for: priority),
                accessibilityLabel: "Priority filter \(priority.title), active"
            ) {
                store.send(.sessionTaskPriorityFilterToggled(priority))
            }
        }

        ForEach(selectedFilteredCategories) { category in
            activeFilterChip(
                title: category.name,
                tint: Color(orbitHex: category.colorHex),
                icon: "tag.fill",
                accessibilityLabel: "Category filter \(category.name), active"
            ) {
                store.send(.sessionTaskCategoryFilterToggled(category.id))
            }
        }
    }

    private var selectedPriorities: [NotePriority] {
        SessionTaskFilterSupport.priorityFilterOrder.filter {
            SessionTaskFilterSupport.isPrioritySelected($0, in: store)
        }
    }

    private var selectedFilteredCategories: [SessionCategoryRecord] {
        SessionTaskFilterSupport.selectedFilteredCategories(in: store)
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
                    .fill(.ultraThinMaterial)
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
}

#if os(iOS)
private struct CompactFilterBarCardModifier: ViewModifier {
    let isCompact: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isCompact {
            content.orbitSurfaceCard()
        } else {
            content
        }
    }
}
#endif

private struct FilterPickerPresentationModifier: ViewModifier {
    let layout: OrbitAdaptiveLayoutValue
    let store: StoreOf<AppFeature>
    @Binding var isPresented: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isPresented, arrowEdge: popoverArrowEdge) {
                SessionTaskFilterPickerPopover(
                    store: store,
                    isTaskFilterPopoverPresented: $isPresented,
                    presentationStyle: .popover
                )
#if os(iOS)
                .presentationCompactAdaptation(.popover)
#endif
            }
    }

#if os(macOS)
    private let popoverArrowEdge: Edge = .bottom
#else
    private let popoverArrowEdge: Edge = .top
#endif
}

private enum SessionTaskFilterPickerPresentationStyle {
    case popover
    case sheet
}

private struct SessionTaskFilterPickerPopover: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Binding var isTaskFilterPopoverPresented: Bool
    let presentationStyle: SessionTaskFilterPickerPresentationStyle

    var body: some View {
        content
            .padding(contentPadding)
#if os(macOS)
            .frame(width: 430)
#else
            .frame(maxWidth: .infinity, alignment: .leading)
#endif
            .padding(.horizontal, popoverOuterHorizontalPadding)
            .padding(.vertical, popoverOuterVerticalPadding)
        .orbitOnExitCommand {
            isTaskFilterPopoverPresented = false
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .orbitFont(.headline)

                Spacer()

                if activeFilterCount > 0 {
                    Button("Clear all", action: clearAllFilters)
                        .buttonStyle(.orbitQuiet)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Priorities")
                    .orbitFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)

                HFlow(itemSpacing: 8, rowSpacing: 8) {
                    ForEach(SessionTaskFilterSupport.priorityFilterOrder, id: \.self) { priority in
                        priorityFilterChip(
                            title: priority.title,
                            count: SessionTaskFilterSupport.countForPriority(priority, in: store),
                            isSelected: SessionTaskFilterSupport.isPrioritySelected(priority, in: store),
                            tint: SessionTaskFilterSupport.priorityFilterTint(for: priority),
                            icon: SessionTaskFilterSupport.priorityFilterIcon(for: priority)
                        ) {
                            store.send(.sessionTaskPriorityFilterToggled(priority))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }

            if !categoriesWithTasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Categories")
                        .orbitFont(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)

                    HFlow(itemSpacing: 8, rowSpacing: 8) {
                        ForEach(categoriesWithTasks) { category in
                            filterChip(
                                title: category.name,
                                count: SessionTaskFilterSupport.countForCategory(category.id, in: store),
                                isSelected: SessionTaskFilterSupport.isCategorySelected(category.id, in: store),
                                tint: Color(orbitHex: category.colorHex)
                            ) {
                                store.send(.sessionTaskCategoryFilterToggled(category.id))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var activeFilterCount: Int {
        SessionTaskFilterSupport.activeFilterCount(in: store)
    }

    private var categoriesWithTasks: [SessionCategoryRecord] {
        SessionTaskFilterSupport.categoriesWithTasks(in: store)
    }

    private var contentPadding: CGFloat {
        presentationStyle == .sheet ? 20 : popoverContentPadding
    }

#if os(macOS)
    private let popoverContentPadding: CGFloat = 14
    private let popoverOuterHorizontalPadding: CGFloat = 0
    private let popoverOuterVerticalPadding: CGFloat = 0
#else
    private let popoverContentPadding: CGFloat = 18
    private let popoverOuterHorizontalPadding: CGFloat = 16
    private let popoverOuterVerticalPadding: CGFloat = 12
#endif

    private func clearAllFilters() {
        store.send(.sessionTaskFiltersCleared)
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
}

@MainActor
private enum SessionTaskFilterSupport {
    static let priorityFilterOrder: [NotePriority] = [
        .high,
        .medium,
        .low,
        .none,
    ]

    static func activeFilterCount(in store: StoreOf<AppFeature>) -> Int {
        store.selectedTaskCategoryFilterIDs.count + store.selectedTaskPriorityFilters.count
    }

    static func isCategorySelected(_ categoryID: UUID, in store: StoreOf<AppFeature>) -> Bool {
        store.selectedTaskCategoryFilterIDs.contains(categoryID)
    }

    static func countForCategory(_ categoryID: UUID, in store: StoreOf<AppFeature>) -> Int {
        store.taskDrafts.filter { draft in
            draft.categories.contains(where: { $0.id == categoryID })
        }
        .count
    }

    static func countForPriority(_ priority: NotePriority, in store: StoreOf<AppFeature>) -> Int {
        store.taskDrafts.filter { draft in
            draft.priority == priority
        }
        .count
    }

    static func categoriesWithTasks(in store: StoreOf<AppFeature>) -> [SessionCategoryRecord] {
        store.categories.filter { countForCategory($0.id, in: store) > 0 }
    }

    static func isPrioritySelected(_ priority: NotePriority, in store: StoreOf<AppFeature>) -> Bool {
        store.selectedTaskPriorityFilters.contains(priority)
    }

    static func selectedFilteredCategories(in store: StoreOf<AppFeature>) -> [SessionCategoryRecord] {
        store.categories.filter { store.selectedTaskCategoryFilterIDs.contains($0.id) }
    }

    static func priorityFilterTint(for priority: NotePriority) -> Color {
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

    static func priorityFilterIcon(for priority: NotePriority) -> String {
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
}
