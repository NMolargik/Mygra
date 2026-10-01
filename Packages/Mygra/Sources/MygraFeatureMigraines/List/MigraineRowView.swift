//
//  MigraineRowView.swift
//  MygraFeatureMigraines
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

struct MigraineRowView: View {
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    let migraine: Migraine

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if migraine.isOngoing {
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(pulseColor(at: context.date))
                        .frame(width: 8)
                        .accessibilityHidden(true)
                }
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(migraine.severity.color)
                    .frame(width: 8)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(primaryTitle)
                        .font(.subheadline)
                        .monospacedDigit()
                        .fontWeight(.bold)

                    Spacer()

                    if migraine.isOngoing {
                        durationPill
                    }

                    HStack(spacing: 4) {
                        metricPill(value: migraine.painLevel, tint: migraine.severity.color)
                        metricPill(value: migraine.stressLevel, tint: .mygraPurple)
                    }
                }

                let triggerCount = migraine.triggers.count + migraine.customTriggers.count
                let hasNote = migraine.note?.isEmpty == false
                if migraine.isPinned || triggerCount > 0 || hasNote {
                    HStack(alignment: .center, spacing: 8) {
                        if migraine.isPinned {
                            Image(systemName: "pin.fill")
                                .padding(.trailing, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(.yellow)
                                .accessibilityLabel(Text("Pinned"))
                        }
                        if triggerCount > 0 {
                            triggerDots(count: triggerCount)
                        }
                        if hasNote, let note = migraine.note {
                            Text("\"\(note)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(height: 30, alignment: .center)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Derived

    private var primaryTitle: String {
        migraine.isOngoing
            ? String(localized: "Ongoing")
            : DateFormatting.compactDateTime(migraine.startDate, useDMY: useDayMonthYearDates)
    }

    /// A color that pulses between clear and purple using a sine wave.
    private func pulseColor(at time: Date, pulseDuration: Double = 1.5) -> Color {
        let t = time.timeIntervalSinceReferenceDate / pulseDuration
        let phase = (sin(t * .pi * 2) + 1) / 2
        return Color.mygraPurple.opacity(phase)
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        if migraine.isOngoing {
            parts.append(String(localized: "Ongoing"))
        } else {
            parts.append(String(localized: "Started \(DateFormatting.dateTime(migraine.startDate, useDMY: useDayMonthYearDates))"))
            if let end = migraine.endDate {
                parts.append(String(localized: "Ended \(DateFormatting.dateTime(end, useDMY: useDayMonthYearDates))"))
            }
        }
        parts.append(String(localized: "Pain \(migraine.painLevel)"))
        parts.append(String(localized: "Stress \(migraine.stressLevel)"))
        let triggerCount = migraine.triggers.count + migraine.customTriggers.count
        if triggerCount > 0 {
            parts.append(String(localized: "Triggers \(triggerCount)"))
        }
        if let note = migraine.note, !note.isEmpty {
            parts.append(String(localized: "Note \(note)"))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Pieces

    private func metricPill(value: Int, tint: Color) -> some View {
        Text("\(value) / 10")
            .font(.caption).bold()
            .monospacedDigit()
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.5)))
    }

    private func triggerDots(count: Int) -> some View {
        let limited = min(count, 10)
        return HStack(spacing: 3) {
            ForEach(0..<limited, id: \.self) { _ in
                Circle()
                    .fill(.secondary)
                    .frame(width: 4, height: 4)
            }
            if count > limited {
                Text("+\(count - limited)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(count) triggers")
        .font(.caption)
    }

    private var durationPill: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let duration = MigraineDates.durationString(context.date.timeIntervalSince(migraine.startDate))
            VStack(spacing: 2) {
                Image(systemName: "clock.fill")
                    .imageScale(.small)
                Text(duration)
                    .font(.caption).bold()
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.mygraBlue))
            .accessibilityLabel("Ongoing duration \(duration)")
        }
    }
}

#Preview("Completed") {
    MigraineRowView(migraine: Migraine.sample())
        .padding()
}

#Preview("Ongoing") {
    MigraineRowView(migraine: Migraine.sampleOngoing())
        .padding()
}
#endif
