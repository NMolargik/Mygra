//
//  MigraineRowView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct MigraineRowView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false
    
    var migraine: Migraine
    var viewModel: MigraineListView.ViewModel

    private var isRegularWidth: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad { return true }
        return hSizeClass == .regular
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Leading status indicator
            if migraine.isOngoing {
                // Animate the leading status bar through severity colors
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                    let tint = animatedSeverityColor(at: context.date)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint)
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
                // Primary line: start + duration, optional pin
                HStack(alignment: .firstTextBaseline) {
                    // Removed TimelineView to ensure immediate updates when date format preference changes
                    Text(primaryTitle)
                        .font(.subheadline)
                        .monospacedDigit()
                        .fontWeight(.bold)
                    
                    Spacer()

                    // Show duration chip for ongoing migraines
                    if migraine.isOngoing {
                        durationPill()
                    }

                    // Pain and stress badges
                    // Localized in Localizable.xcstrings:
                    // "migraine_pain" = "Pain";
                    // "migraine_stress" = "Stress";
                    HStack(spacing: 4) {
                        metricPill(
                            value: "\(migraine.painLevel)",
                            tint: migraine.severity.color,
                        )
                        metricPill(
                            value: "\(migraine.stressLevel)",
                            tint: .mygraPurple,
                        )
                    }
                }

                // Secondary line: triggers as dots + note
                let triggerCount = migraine.triggers.count + migraine.customTriggers.count
                let hasNote = (migraine.note?.isEmpty == false)
                let hasSecondary = migraine.isPinned || triggerCount > 0 || hasNote

                if hasSecondary {
                    HStack(alignment: .center, spacing: 8) {
                        if migraine.isPinned {
                            // Localized in Localizable.xcstrings:
                            // "migraine_pinned" = "Pinned";
                            Label {
                                Text("Pinned")
                                    .font(.caption).bold()
                            } icon: {
                                Image(systemName: "pin.fill")
                            }
                            .labelStyle(.iconOnly)
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

    // MARK: - Derived strings

    private var primaryTitle: String {
        if migraine.isOngoing {
            return "Ongoing"
        } else {
            return DateFormatting.compactDateTime(migraine.startDate, useDMY: useDayMonthYearDates)
        }
    }

    private var startString: String {
        // Use the global formatting preference
        DateFormatting.dateTime(migraine.startDate, useDMY: useDayMonthYearDates)
    }

    private func dateRangeShort(for migraine: Migraine) -> String {
        if migraine.isOngoing {
            return "Ongoing"
        }
        // Show the start date/time using the preferred global format
        return DateFormatting.dateTime(migraine.startDate, useDMY: useDayMonthYearDates)
    }

    private func liveDurationString(now: Date) -> String {
        let end = migraine.endDate ?? now
        let s = max(0, Int(end.timeIntervalSince(migraine.startDate)))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, sec)
        } else {
            return String(format: "%dm %02ds", m, sec)
        }
    }
    
    // MARK: - Ongoing color pulse helper
    /// Returns a color that pulses between clear and indigo using a sine wave.
    private func animatedSeverityColor(at time: Date, pulseDuration: Double = 1.5) -> Color {
        let t = time.timeIntervalSinceReferenceDate / pulseDuration
        // Use sine wave for smooth pulse (0 to 1 to 0)
        let phase = (sin(t * .pi * 2) + 1) / 2 // Normalized 0...1
        return Color.mygraPurple.opacity(phase)
    }


    private var accessibilitySummary: String {
        var parts: [String] = []
        if migraine.isOngoing {
            parts.append("Ongoing")
        } else {
            parts.append("Started \(startString)")
            if let end = migraine.endDate {
                parts.append("Ended \(DateFormatting.dateTime(end, useDMY: useDayMonthYearDates))")
            }
        }
        parts.append("Pain \(migraine.painLevel)")
        parts.append("Stress \(migraine.stressLevel)")
        let triggerCount = migraine.triggers.count + migraine.customTriggers.count
        if triggerCount > 0 {
            parts.append("Triggers \(triggerCount)")
        }
        if let note = migraine.note, !note.isEmpty {
            parts.append("Note \(note)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - UI helpers

    private func metricPill(value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value) / 10")
                .font(.caption).bold()
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.5))
        )
    }

    @ContentBuilder
    private func triggerDots(count: Int) -> some View {
        let limited = min(count, 10)
        HStack(spacing: 3) {
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
    
    
    @ContentBuilder
    private func durationPill() -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            VStack(spacing: 2) {
                Image(systemName: "clock.fill")
                    .imageScale(.small)
                Text(liveDurationString(now: now))
                    .font(.caption).bold()
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.mygraBlue)
            )
            .accessibilityLabel("Ongoing duration \(liveDurationString(now: now))")
        }
    }
}

#Preview {
    MigraineRowView(
        migraine: Migraine(pinned: true, startDate: Date.now, painLevel: 7, stressLevel: 6),
        viewModel: MigraineListView.ViewModel()
    )
    .frame(height: 60)
}

#Preview("Ongoing Migraine") {
    MigraineRowView(
        migraine: Migraine(
            pinned: false,
            startDate: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now,
            endDate: nil,
            painLevel: 8,
            stressLevel: 5,
            triggers: []),
        viewModel: MigraineListView.ViewModel()
    )
    .frame(height: 60)
}

