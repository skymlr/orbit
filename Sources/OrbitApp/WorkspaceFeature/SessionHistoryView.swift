import ComposableArchitecture
import Foundation
import SwiftUI

struct SessionHistoryView: View {
    private enum Layout {
        static let contentMaxWidth: CGFloat = 700
    }

    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    let historyDayGroups: [HistoryDayGroup]
    let selectedHistoryDay: Date
    let selectedHistorySessionID: UUID?
    let onExitHistoryMode: () -> Void
    let onSelectHistorySession: (UUID) -> Void
    let onExportSession: (UUID) -> Void

    @State private var historyTaskFilter: HistoryTaskFilter = .completed

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Read-Only Session History")
                .font(.title3.weight(.bold))

            if let activeSession = store.activeSession {
                CurrentSessionHistoryBanner(
                    session: activeSession,
                    onBackToLiveSession: onExitHistoryMode
                )
            } else {
                noActiveSessionBanner
            }

            if historyDayGroups.isEmpty {
                historyContentUnavailableState(
                    message: "No completed sessions yet. End a session to build your history timeline."
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(SessionHistoryBrowserSupport.dayLabel(selectedHistoryDay))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.cyan)

                    Text("\(selectedHistoryDaySessions.count) \(selectedHistoryDaySessions.count == 1 ? "session" : "sessions")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if selectedHistoryDaySessions.isEmpty {
                    historyContentUnavailableState(
                        message: "No sessions on this day. Use the arrows or calendar to jump to a day with saved sessions."
                    )
                } else {
                    HistorySessionStripView(
                        sessions: selectedHistoryDaySessions,
                        selectedSessionID: selectedHistorySession?.id,
                        onSelect: onSelectHistorySession,
                        onRename: renameSession(sessionID:name:),
                        onDelete: deleteSession(sessionID:),
                        onExport: onExportSession
                    )

                    if let selectedHistorySession {
                        HistoryTaskListView(
                            session: selectedHistorySession,
                            filteredTasks: historyFilteredTasks,
                            historyTaskFilter: $historyTaskFilter
                        )
                    }
                }
            }
        }
        .frame(maxWidth: Layout.contentMaxWidth, alignment: .leading)
        .transition(.orbitMicro)
    }

    private var noActiveSessionBanner: some View {
        HStack(spacing: 10) {
            Text("No active session. You are browsing archived history.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Exit History") {
                onExitHistoryMode()
            }
            .buttonStyle(.orbitSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var selectedHistoryDaySessions: [FocusSessionRecord] {
        SessionHistoryBrowserSupport.sessions(on: selectedHistoryDay, from: historyDayGroups)
    }

    private var selectedHistorySession: FocusSessionRecord? {
        SessionHistoryBrowserSupport.resolveSelectedSession(
            id: selectedHistorySessionID,
            on: selectedHistoryDay,
            groups: historyDayGroups
        )
    }

    private var historyFilteredTasks: [FocusTaskRecord] {
        guard let selectedHistorySession else { return [] }
        return SessionHistoryBrowserSupport.filteredTasks(
            for: selectedHistorySession,
            filter: historyTaskFilter
        )
    }

    private func historyContentUnavailableState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Sessions To Show")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func renameSession(sessionID: UUID, name: String) {
        store.send(.settingsRenameSessionTapped(sessionID, name))
    }

    private func deleteSession(sessionID: UUID) {
        store.send(.settingsDeleteSessionTapped(sessionID))
    }
}

private struct CurrentSessionHistoryBanner: View {
    let session: FocusSessionRecord
    let onBackToLiveSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Session")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(session.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                Button("Back to Live Session") {
                    onBackToLiveSession()
                }
                .buttonStyle(.orbitPrimary)
            }

            HStack(spacing: 8) {
                Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                Text("•")
                Text("Started \(session.startedAt, style: .time)")
                Text("•")
                Text("Elapsed \(session.startedAt, style: .timer)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.cyan.opacity(0.62), lineWidth: 1)
                )
        )
    }
}

private struct HistorySessionStripView: View {
    let sessions: [FocusSessionRecord]
    let selectedSessionID: UUID?
    let onSelect: (UUID) -> Void
    let onRename: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onExport: (UUID) -> Void

    @State private var menuSessionID: UUID?
    @State private var menuMode: MenuMode = .actions
    @State private var renameDraft = ""
    @State private var deleteConfirmationSessionID: UUID?

    private enum MenuMode {
        case actions
        case rename
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(sessions) { session in
                    sessionButton(for: session)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(
            "Delete Session?",
            isPresented: $deleteConfirmationSessionID.isPresented
        ) {
            if let session = sessions.first(where: { $0.id == deleteConfirmationSessionID }) {
                Button("Delete \"\(session.name)\"", role: .destructive) {
                    onDelete(session.id)
                    deleteConfirmationSessionID = nil
                }
            } else {
                Button("Delete Session", role: .destructive) {
                    if let sessionID = deleteConfirmationSessionID {
                        onDelete(sessionID)
                    }
                    deleteConfirmationSessionID = nil
                }
            }

            Button("Cancel", role: .cancel) {
                deleteConfirmationSessionID = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func sessionButton(for session: FocusSessionRecord) -> some View {
        let isSelected = session.id == selectedSessionID
        let taskCountLabel = "\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")"

        return ZStack(alignment: .topTrailing) {
            Button {
                onSelect(session.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text("Started \(session.startedAt, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(taskCountLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .padding(.trailing, 24)
                .frame(minWidth: 164, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.cyan.opacity(0.18) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.cyan.opacity(0.86) : Color.white.opacity(0.22), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.name)
            .accessibilityHint("Open this session in read-only mode")

            Button {
                menuSessionID = session.id
                menuMode = .actions
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .popover(
                isPresented: $menuSessionID[isPresenting: session.id],
                arrowEdge: .top
            ) {
                sessionMenuPopover(for: session)
            }
        }
    }

    @ViewBuilder
    private func sessionMenuPopover(for session: FocusSessionRecord) -> some View {
        switch menuMode {
        case .actions:
            VStack(alignment: .leading, spacing: 8) {
                Button("Rename") {
                    renameDraft = session.name
                    menuMode = .rename
                }
                .buttonStyle(.orbitSecondary)

                Button("Export") {
                    onExport(session.id)
                    closeMenu()
                }
                .buttonStyle(.orbitSecondary)

                Button("Delete", role: .destructive) {
                    deleteConfirmationSessionID = session.id
                    closeMenu()
                }
                .buttonStyle(.orbitDestructive)
            }
            .padding(10)
            .frame(width: 170, alignment: .leading)

        case .rename:
            VStack(alignment: .leading, spacing: 8) {
                Text("Rename Session")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Session name", text: $renameDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveRename(for: session.id)
                    }

                HStack {
                    Button("Cancel") {
                        menuMode = .actions
                    }
                    .buttonStyle(.orbitSecondary)

                    Spacer()

                    Button("Save") {
                        saveRename(for: session.id)
                    }
                    .buttonStyle(.orbitPrimary)
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(10)
            .frame(width: 240, alignment: .leading)
        }
    }

    private func saveRename(for sessionID: UUID) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRename(sessionID, trimmed)
        closeMenu()
    }

    private func closeMenu() {
        menuSessionID = nil
        menuMode = .actions
    }
}

private struct HistoryTaskListView: View {
    let session: FocusSessionRecord
    let filteredTasks: [FocusTaskRecord]
    @Binding var historyTaskFilter: HistoryTaskFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.title3.weight(.semibold))

                HStack(spacing: 8) {
                    Text("Started \(session.startedAt, style: .time)")

                    if let endedAt = session.endedAt {
                        Text("•")
                        Text("Ended \(endedAt, style: .time)")
                    }

                    Text("•")
                    Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            OrbitSegmentedControl(
                "Task filter",
                selection: $historyTaskFilter,
                options: HistoryTaskFilter.allCases
            ) { filter in
                filter.title
            }
            .frame(maxWidth: 320)

            if filteredTasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No tasks for this filter")
                        .font(.subheadline.weight(.semibold))
                    Text("Try switching between Completed, All, and Open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredTasks) { task in
                            HistoryTaskRowView(task: task)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
            }
        }
    }
}

struct HistoryCalendarPickerView: View {
    let availableDays: Set<Date>
    let selectedDay: Date
    let onSelectDay: (Date) -> Void

    @State private var displayedMonthStart: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(
        availableDays: Set<Date>,
        selectedDay: Date,
        onSelectDay: @escaping (Date) -> Void
    ) {
        self.availableDays = availableDays
        self.selectedDay = selectedDay
        self.onSelectDay = onSelectDay
        _displayedMonthStart = State(initialValue: Self.monthStart(for: selectedDay, calendar: .current))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.orbitQuiet)

                Spacer()

                Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.orbitQuiet)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthDayCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear
                            .frame(height: 26)
                    }
                }
            }
        }
    }

    private var normalizedAvailableDays: Set<Date> {
        Set(availableDays.map { calendar.startOfDay(for: $0) })
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        guard symbols.indices.contains(firstWeekdayIndex) else { return symbols }
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    private var monthDayCells: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: displayedMonthStart)
        let leadingEmptyCells = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells = Array(repeating: Date?.none, count: leadingEmptyCells)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: displayedMonthStart) {
                cells.append(date)
            }
        }

        let trailingCells = (7 - (cells.count % 7)) % 7
        if trailingCells > 0 {
            cells.append(contentsOf: Array(repeating: Date?.none, count: trailingCells))
        }
        return cells
    }

    private func dayButton(_ day: Date) -> some View {
        let normalizedDay = calendar.startOfDay(for: day)
        let isEnabled = normalizedAvailableDays.contains(normalizedDay)
        let isSelected = calendar.isDate(normalizedDay, inSameDayAs: selectedDay)
        let dayNumber = calendar.component(.day, from: normalizedDay)
        let backgroundColor = dayBackgroundColor(isEnabled: isEnabled, isSelected: isSelected)
        let borderColor = dayBorderColor(isEnabled: isEnabled, isSelected: isSelected)
        let foregroundColor = dayForegroundColor(isEnabled: isEnabled)

        return Button {
            onSelectDay(normalizedDay)
        } label: {
            Text("\(dayNumber)")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .foregroundStyle(foregroundColor)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(normalizedDay.formatted(date: .abbreviated, time: .omitted))
        .accessibilityHint(isEnabled ? "Open history for this day" : "No historical sessions on this day")
    }

    private func moveMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: displayedMonthStart) else { return }
        displayedMonthStart = Self.monthStart(for: month, calendar: calendar)
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func dayBackgroundColor(isEnabled: Bool, isSelected: Bool) -> Color {
        if isSelected { return Color.cyan.opacity(0.30) }
        if isEnabled { return Color.cyan.opacity(0.16) }
        return Color.clear
    }

    private func dayBorderColor(isEnabled: Bool, isSelected: Bool) -> Color {
        if isSelected { return Color.cyan.opacity(0.92) }
        if isEnabled { return Color.cyan.opacity(0.45) }
        return Color.white.opacity(0.12)
    }

    private func dayForegroundColor(isEnabled: Bool) -> Color {
        isEnabled ? Color.primary : Color.secondary.opacity(0.35)
    }
}

private extension Optional {
    var isPresented: Bool {
        get { self != nil }
        set {
            guard !newValue else { return }
            self = nil
        }
    }
}

private extension Optional where Wrapped: Equatable {
    subscript(isPresenting value: Wrapped) -> Bool {
        get { self == value }
        set {
            guard !newValue else { return }
            if self == value {
                self = nil
            }
        }
    }
}
