//
//  MigraineCalendarView.swift
//  MygraFeatureCalendar
//
//  Month calendar with an optional tag filter and the selected day's migraines.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct MigraineCalendarView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(TagDataModel.self) private var tagData

    /// When provided, rows are buttons that call back instead of pushing a navigation value.
    var onSelectMigraine: ((UUID) -> Void)?

    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var selectedTag: MigraineTag?

    private let calendar = Calendar.current

    public init(onSelectMigraine: ((UUID) -> Void)? = nil) {
        self.onSelectMigraine = onSelectMigraine
    }

    private var filteredMigraines: [Migraine] {
        guard let selectedTag else { return migraineData.migraines }
        return migraineData.migraines.filter { ($0.tags ?? []).contains { $0.id == selectedTag.id } }
    }

    private var migrainesForSelectedDate: [Migraine] {
        MigraineStatistics.migraines(filteredMigraines, on: selectedDate, calendar: calendar)
    }

    public var body: some View {
        VStack(spacing: 0) {
            MonthHeaderView(
                displayedMonth: displayedMonth,
                onPrevious: { changeMonth(by: -1) },
                onNext: { changeMonth(by: 1) },
                onToday: goToToday
            )
            .padding(.horizontal)
            .padding(.vertical, 8)

            if !tagData.tags.isEmpty {
                TagFilterView(tags: tagData.tags, selectedTag: $selectedTag)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            CalendarGridView(displayedMonth: displayedMonth, selectedDate: $selectedDate, migraines: filteredMigraines)
                .padding(.horizontal)

            Divider()
                .padding(.top, 16)

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
                            if let onSelectMigraine {
                                Button {
                                    onSelectMigraine(migraine.id)
                                } label: {
                                    MigraineCalendarRowView(migraine: migraine)
                                }
                                .tint(.primary)
                            } else {
                                NavigationLink(value: migraine.id) {
                                    MigraineCalendarRowView(migraine: migraine)
                                }
                            }
                        }
                    } header: {
                        Text("\(migrainesForSelectedDate.count) migraines on \(formattedDate(selectedDate))")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Calendar")
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = newMonth
        }
    }

    private func goToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = Date()
            selectedDate = Date()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Month header

private struct MonthHeaderView: View {
    let displayedMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

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

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
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

// MARK: - Tag filter

private struct TagFilterView: View {
    let tags: [MigraineTag]
    @Binding var selectedTag: MigraineTag?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: String(localized: "All"), color: .gray, isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(tags) { tag in
                    FilterChip(label: tag.name, color: tag.color, isSelected: selectedTag?.id == tag.id) {
                        selectedTag = tag
                    }
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
                .background(Capsule().fill(isSelected ? color.opacity(0.2) : Color.clear))
                .overlay(Capsule().strokeBorder(color, lineWidth: isSelected ? 0 : 1))
                .foregroundStyle(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct MigraineCalendarRowView: View {
    let migraine: Migraine

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(migraine.severity.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(migraine.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.headline)
                if migraine.isOngoing {
                    Text("Ongoing")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else if let duration = migraine.duration {
                    Text(MigraineDates.compactDurationString(duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Pain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(migraine.painLevel)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

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
}

#Preview("Calendar View") {
    NavigationStack {
        MigraineCalendarView()
    }
    .previewEnvironment()
}
#endif
