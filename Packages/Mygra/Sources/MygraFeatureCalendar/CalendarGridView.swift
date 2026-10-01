//
//  CalendarGridView.swift
//  MygraFeatureCalendar
//
//  A month grid showing days with migraine severity indicators.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

struct CalendarGridView: View {
    let displayedMonth: Date
    @Binding var selectedDate: Date
    let migraines: [Migraine]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            migrainesForDay: MigraineStatistics.migraines(migraines, on: date, calendar: calendar),
                            onTap: { selectedDate = date }
                        )
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    /// The month's days padded to whole weeks; nil marks days of adjacent months.
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        var days: [Date?] = []
        var current = firstWeek.start
        for _ in 0..<42 {
            days.append(calendar.isDate(current, equalTo: displayedMonth, toGranularity: .month) ? current : nil)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        while days.count > 7 && days.suffix(7).allSatisfy({ $0 == nil }) {
            days.removeLast(7)
        }
        return days
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let migrainesForDay: [Migraine]
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : (isToday ? .mygraBlue : .primary))

                if migrainesForDay.isEmpty {
                    Color.clear.frame(height: 6)
                } else {
                    HStack(spacing: 2) {
                        ForEach(migrainesForDay.prefix(3)) { migraine in
                            Circle()
                                .fill(migraine.severity.color)
                                .frame(width: 6, height: 6)
                        }
                        if migrainesForDay.count > 3 {
                            Text("+")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.mygraBlue : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let dateString = date.formatted(date: .abbreviated, time: .omitted)
        if migrainesForDay.isEmpty {
            return dateString
        }
        return String(localized: "\(dateString), \(migrainesForDay.count) migraines")
    }
}

#Preview("Calendar Grid") {
    CalendarGridView(displayedMonth: Date(), selectedDate: .constant(Date()), migraines: [Migraine.sample()])
        .padding()
}
#endif
