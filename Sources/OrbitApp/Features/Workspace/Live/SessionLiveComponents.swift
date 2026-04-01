import SwiftUI

struct SessionLiveNoActiveSessionView<Label: View>: View {
    let maxButtonWidth: CGFloat?
    let helpText: String
    let verticalOffset: CGFloat
    let action: () -> Void

    private let label: Label

    init(
        maxButtonWidth: CGFloat?,
        helpText: String,
        verticalOffset: CGFloat,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.maxButtonWidth = maxButtonWidth
        self.helpText = helpText
        self.verticalOffset = verticalOffset
        self.action = action
        self.label = label()
    }

    var body: some View {
        VStack {
            Button(action: action) {
                label
            }
            .buttonStyle(.orbitHero)
            .frame(maxWidth: maxButtonWidth ?? .infinity)
            .help(helpText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: verticalOffset)
    }
}

struct SessionLiveLoadingStateView: View {
    let verticalOffset: CGFloat

    var body: some View {
        OrbitLaunchLoadingScreen(
            message: "Loading active session...",
            showsBackground: false
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: verticalOffset)
    }
}

struct SessionLiveErrorStateView: View {
    let message: String
    let verticalOffset: CGFloat
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .orbitFont(.title2)
                .foregroundStyle(.orange)

            Text("Could not load active session")
                .orbitFont(.headline)

            Text(message)
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 480)

            Button("Retry", action: retryAction)
                .buttonStyle(.orbitSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: verticalOffset)
    }
}

struct SessionLiveTaskListView<Overview: View, FilterBar: View, TaskContent: View>: View {
    let usesPhoneListLayout: Bool
    let hasSelectedFilters: Bool
    let topPadding: CGFloat
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    let trailingPadding: CGFloat
    @Binding var focusedTaskID: UUID?

    private let overviewContent: Overview
    private let filterBar: FilterBar
    private let taskContent: TaskContent

    init(
        usesPhoneListLayout: Bool,
        hasSelectedFilters: Bool,
        topPadding: CGFloat,
        horizontalPadding: CGFloat,
        bottomPadding: CGFloat,
        trailingPadding: CGFloat,
        focusedTaskID: Binding<UUID?>,
        @ViewBuilder overviewContent: () -> Overview,
        @ViewBuilder filterBar: () -> FilterBar,
        @ViewBuilder taskContent: () -> TaskContent
    ) {
        self.usesPhoneListLayout = usesPhoneListLayout
        self.hasSelectedFilters = hasSelectedFilters
        self.topPadding = topPadding
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.trailingPadding = trailingPadding
        self._focusedTaskID = focusedTaskID
        self.overviewContent = overviewContent()
        self.filterBar = filterBar()
        self.taskContent = taskContent()
    }

    var body: some View {
        Group {
            if usesPhoneListLayout {
                phoneListContent
            } else {
                scrollViewContent
            }
        }
#if os(macOS)
        .scrollEdgeEffectStyle(.hard, for: .top)
#endif
    }

    private var scrollViewContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 14,
                    pinnedViews: hasSelectedFilters ? [.sectionHeaders] : []
                ) {
                    overviewContent

                    Section {
                        taskContent
                    } header: {
                        if hasSelectedFilters {
                            filterBar
                        }
                    }
                }
                .padding(.top, topPadding)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
                .padding(.trailing, trailingPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .onChange(of: focusedTaskID) { _, _ in
                scrollFocusedTaskIfNeeded(using: scrollProxy)
            }
        }
    }

    private var phoneListContent: some View {
        List {
            overviewContent
                .orbitPhoneListRow(
                    insets: EdgeInsets(
                        top: topPadding,
                        leading: horizontalPadding,
                        bottom: 14,
                        trailing: horizontalPadding + trailingPadding
                    )
                )

            phoneTaskSectionContent
                .orbitPhoneListRow(
                    insets: EdgeInsets(
                        top: 0,
                        leading: horizontalPadding,
                        bottom: bottomPadding,
                        trailing: horizontalPadding + trailingPadding
                    )
                )
        }
        .orbitPhoneListStyle()
    }

    @ViewBuilder
    private var phoneTaskSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasSelectedFilters {
                filterBar
                    .padding(.horizontal, max(0, horizontalPadding - 12))
                    .padding(.top, 4)
                    .textCase(nil)
            }

            taskContent
        }
    }

    private func scrollFocusedTaskIfNeeded(using scrollProxy: ScrollViewProxy) {
        guard let focusedTaskID else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            scrollProxy.scrollTo(focusedTaskID, anchor: .top)
        }
    }
}
