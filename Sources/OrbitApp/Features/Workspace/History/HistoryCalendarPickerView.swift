import SwiftUI

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
