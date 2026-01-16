//
//  CalendarGridView.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import SwiftUI

/// A month grid component showing days with migraine indicators.
struct CalendarGridView: View {
    let displayedMonth: Date
    @Binding var selectedDate: Date
    let migraines: [Migraine]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            migrainesForDay: migrainesOn(date),
                            onTap: {
                                selectedDate = date
                            }
                        )
                    } else {
                        // Empty cell for days outside the month
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns an array of optional Dates for the month grid.
    /// Nil values represent days from adjacent months (leading/trailing).
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        var current = monthFirstWeek.start

        // Generate 6 weeks (42 days) to ensure we cover all months
        for _ in 0..<42 {
            if calendar.isDate(current, equalTo: displayedMonth, toGranularity: .month) {
                days.append(current)
            } else {
                days.append(nil)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        // Trim trailing empty rows
        while days.count > 7 && days.suffix(7).allSatisfy({ $0 == nil }) {
            days.removeLast(7)
        }

        return days
    }

    /// Returns migraines that occurred on the given date.
    private func migrainesOn(_ date: Date) -> [Migraine] {
        migraines.filter { migraine in
            calendar.isDate(migraine.startDate, inSameDayAs: date)
        }
    }
}

// MARK: - Day Cell

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

                // Migraine indicator dots
                if !migrainesForDay.isEmpty {
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
                } else {
                    // Placeholder to maintain consistent height
                    Color.clear.frame(height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.mygraBlue : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: date)

        if migrainesForDay.isEmpty {
            return dateString
        } else {
            return "\(dateString), \(migrainesForDay.count) migraine\(migrainesForDay.count == 1 ? "" : "s")"
        }
    }
}

#Preview("Calendar Grid") {
    CalendarGridView(
        displayedMonth: Date(),
        selectedDate: .constant(Date()),
        migraines: []
    )
    .padding()
}
