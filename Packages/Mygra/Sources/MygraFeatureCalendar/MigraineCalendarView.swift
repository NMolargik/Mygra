//
//  MigraineCalendarView.swift
//  MygraFeatureCalendar
//
//  Month calendar with an optional tag filter and the selected day's migraines. Swipe
//  horizontally to change months; the month title animates numerically.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct MigraineCalendarView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(TagDataModel.self) private var tagData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var selectedTag: MigraineTag?

    private let calendar = Calendar.current

    public init() {}

    private var filteredMigraines: [Migraine] {
        guard let selectedTag else { return migraineData.migraines }
        return migraineData.migraines.filter { ($0.tags ?? []).contains { $0.id == selectedTag.id } }
    }

    private var migrainesForSelectedDate: [Migraine] {
        MigraineStatistics.migraines(filteredMigraines, on: selectedDate, calendar: calendar)
    }

    private var monthMigraineCount: Int {
        filteredMigraines.filter { calendar.isDate($0.startDate, equalTo: displayedMonth, toGranularity: .month) }.count
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 0) {
                    calendarPane
                        .frame(maxWidth: 520)
                    Divider()
                    dayList
                }
            } else {
                VStack(spacing: 0) {
                    calendarPane
                    Divider().padding(.top, Brand.Space.lg)
                    dayList
                }
            }
        }
        .navigationTitle("Calendar")
        .navigationSubtitleIfAvailable(monthSubtitle)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button(action: goToToday) {
                    Label("Today", systemImage: "calendar.circle")
                }
                .disabled(calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) && calendar.isDateInToday(selectedDate))
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }

    private var monthSubtitle: String {
        monthMigraineCount == 1
            ? String(localized: "1 migraine this month")
            : String(localized: "\(monthMigraineCount) migraines this month")
    }

    // MARK: - Panes

    private var calendarPane: some View {
        VStack(spacing: 0) {
            MonthHeaderView(
                displayedMonth: displayedMonth,
                onPrevious: { changeMonth(by: -1) },
                onNext: { changeMonth(by: 1) }
            )
            .padding(.horizontal)
            .padding(.vertical, Brand.Space.sm)

            if !tagData.tags.isEmpty {
                TagFilterView(tags: tagData.tags, selectedTag: $selectedTag)
                    .padding(.horizontal)
                    .padding(.bottom, Brand.Space.sm)
            }

            CalendarGridView(displayedMonth: displayedMonth, selectedDate: $selectedDate, migraines: filteredMigraines)
                .padding(.horizontal)
                .id(calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            changeMonth(by: value.translation.width < 0 ? 1 : -1)
                        }
                )
                .accessibilityAction(named: Text("Next month")) { changeMonth(by: 1) }
                .accessibilityAction(named: Text("Previous month")) { changeMonth(by: -1) }
        }
    }

    @ContentBuilder
    private var dayList: some View {
        if migrainesForSelectedDate.isEmpty {
            ContentUnavailableView {
                Label("No Migraines", systemImage: "calendar.badge.checkmark")
            } description: {
                Text("No migraines recorded on \(formattedDate(selectedDate))")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(migrainesForSelectedDate) { migraine in
                        NavigationLink(value: migraine.id) {
                            MigraineCalendarRowView(migraine: migraine)
                        }
                        .hoverHighlight()
                    }
                } header: {
                    Text(migrainesForSelectedDate.count == 1
                         ? String(localized: "1 migraine on \(formattedDate(selectedDate))")
                         : String(localized: "\(migrainesForSelectedDate.count) migraines on \(formattedDate(selectedDate))"))
                }
            }
            .listStyle(.insetGrouped)
            .animation(.snappy, value: selectedDate)
        }
    }

    // MARK: - Actions

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        Haptics.lightImpact()
        withAnimation(.snappy) {
            displayedMonth = newMonth
        }
    }

    private func goToToday() {
        Haptics.lightImpact()
        withAnimation(.snappy) {
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

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Label("Previous month", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
            }
            .glassActionButton(tint: .mygraPurple, prominent: false)
            .hoverHighlight()

            Spacer()

            VStack(spacing: 2) {
                Text(displayedMonth, format: .dateTime.month(.wide))
                    .font(.title2.weight(.bold))
                    .contentTransition(.numericText())
                Text(displayedMonth, format: .dateTime.year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onNext) {
                Label("Next month", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
            }
            .glassActionButton(tint: .mygraPurple, prominent: false)
            .hoverHighlight()
        }
    }
}

// MARK: - Tag filter

private struct TagFilterView: View {
    let tags: [MigraineTag]
    @Binding var selectedTag: MigraineTag?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Space.sm) {
                FilterChip(label: String(localized: "All"), color: .gray, isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(tags) { tag in
                    FilterChip(label: tag.name, color: tag.color, isSelected: selectedTag?.id == tag.id) {
                        selectedTag = tag
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by tag")
    }
}

private struct FilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.lightImpact()
            withAnimation(.snappy) { onTap() }
        } label: {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, Brand.Space.md)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(isSelected ? color.opacity(0.22) : Color.clear))
                .overlay(Capsule(style: .continuous).strokeBorder(color.opacity(isSelected ? 0 : 0.6), lineWidth: 1))
                .foregroundStyle(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Row

private struct MigraineCalendarRowView: View {
    let migraine: Migraine

    var body: some View {
        HStack(spacing: Brand.Space.md) {
            Circle()
                .fill(migraine.severity.color.gradient)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Text(migraine.startDate, format: .dateTime.hour().minute())
                    .font(.headline)
                if migraine.isOngoing {
                    Label("Ongoing", systemImage: "waveform.path.ecg")
                        .font(.subheadline)
                        .foregroundStyle(.mygraPurple)
                } else if let duration = migraine.duration {
                    Label(MigraineDates.compactDurationString(duration), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Pain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(migraine.painLevel, format: .number)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(migraine.severity.color)
            }

            if let tags = migraine.tags, !tags.isEmpty {
                HStack(spacing: Brand.Space.xs) {
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
                .accessibilityLabel(Text("\(tags.count) tags"))
            }
        }
        .padding(.vertical, Brand.Space.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Calendar View") {
    NavigationStack {
        MigraineCalendarView()
    }
    .previewEnvironment()
}
#endif
