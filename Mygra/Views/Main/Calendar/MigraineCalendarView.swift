//
//  MigraineCalendarView.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import SwiftUI
import SwiftData

/// Calendar view showing migraines by month with day selection.
struct MigraineCalendarView: View {
    @Environment(MigraineManager.self) private var migraineManager
    @Environment(TagManager.self) private var tagManager

    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()
    @State private var selectedTag: MigraineTag? = nil

    private let calendar = Calendar.current

    private var filteredMigraines: [Migraine] {
        var migraines = migraineManager.migraines

        // Filter by selected tag if any
        if let tag = selectedTag {
            migraines = migraines.filter { ($0.tags ?? []).contains { $0.id == tag.id } }
        }

        return migraines
    }

    private var migrainesForSelectedDate: [Migraine] {
        filteredMigraines.filter { migraine in
            calendar.isDate(migraine.startDate, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation header
            MonthHeaderView(
                displayedMonth: $displayedMonth,
                onPrevious: { changeMonth(by: -1) },
                onNext: { changeMonth(by: 1) },
                onToday: { goToToday() }
            )
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Tag filter (if tags exist)
            if !tagManager.tags.isEmpty {
                TagFilterView(
                    tags: tagManager.tags,
                    selectedTag: $selectedTag
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Calendar grid
            CalendarGridView(
                displayedMonth: displayedMonth,
                selectedDate: $selectedDate,
                migraines: filteredMigraines
            )
            .padding(.horizontal)

            Divider()
                .padding(.top, 16)

            // Selected day migraines
            if migrainesForSelectedDate.isEmpty {
                ContentUnavailableView(
                    "No Migraines",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("No migraines recorded on \(formattedDate(selectedDate))")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(migrainesForSelectedDate) { migraine in
                            NavigationLink(value: migraine.id) {
                                MigraineCalendarRowView(migraine: migraine)
                            }
                        }
                    } header: {
                        Text("\(migrainesForSelectedDate.count) migraine\(migrainesForSelectedDate.count == 1 ? "" : "s") on \(formattedDate(selectedDate))")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Calendar")
        .task {
            await migraineManager.refresh()
            await tagManager.refresh()
        }
    }

    // MARK: - Navigation

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newMonth
            }
        }
    }

    private func goToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = Date()
            selectedDate = Date()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Month Header View

private struct MonthHeaderView: View {
    @Binding var displayedMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthYearString)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")

            Button(action: onToday) {
                Text("Today")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .padding(.leading, 8)
        }
    }
}

// MARK: - Tag Filter View

private struct TagFilterView: View {
    let tags: [MigraineTag]
    @Binding var selectedTag: MigraineTag?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                FilterChip(
                    label: "All",
                    color: .gray,
                    isSelected: selectedTag == nil,
                    onTap: { selectedTag = nil }
                )

                // Tag chips
                ForEach(tags) { tag in
                    FilterChip(
                        label: tag.name,
                        color: tag.color,
                        isSelected: selectedTag?.id == tag.id,
                        onTap: { selectedTag = tag }
                    )
                }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.2) : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(color, lineWidth: isSelected ? 0 : 1)
                )
                .foregroundStyle(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Migraine Calendar Row View

private struct MigraineCalendarRowView: View {
    let migraine: Migraine

    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(migraine.severity.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                // Time
                Text(timeString)
                    .font(.headline)

                // Duration or ongoing
                if migraine.isOngoing {
                    Text("Ongoing")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else if let duration = migraine.duration {
                    Text(durationString(duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Pain level
            VStack(alignment: .trailing, spacing: 2) {
                Text("Pain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(migraine.painLevel)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            // Tags
            if let tags = migraine.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(2)) { tag in
                        Circle()
                            .fill(tag.color)
                            .frame(width: 8, height: 8)
                    }
                    if tags.count > 2 {
                        Text("+\(tags.count - 2)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: migraine.startDate)
    }

    private func durationString(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview("Calendar View") {
    NavigationStack {
        MigraineCalendarView()
    }
}
