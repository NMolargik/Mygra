//
//  MigraineRowView.swift
//  MygraFeatureMigraines
//
//  One migraine in the list: a severity bar, the date (or live elapsed time), pain and
//  stress chips, and a quiet second line with pin, trigger count, and note.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

struct MigraineRowView: View {
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    let migraine: Migraine

    var body: some View {
        HStack(alignment: .center, spacing: Brand.Space.md) {
            severityBar

            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
                    if migraine.isOngoing {
                        Label("Ongoing", systemImage: "waveform.path.ecg")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.mygraPurple)
                            .symbolEffect(.pulse, options: .repeating)
                    } else {
                        Text(DateFormatting.compactDateTime(migraine.startDate, useDMY: useDayMonthYearDates))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }

                    Spacer(minLength: Brand.Space.xs)

                    HStack(spacing: Brand.Space.xs) {
                        levelChip(migraine.painLevel, systemImage: "bolt.fill", tint: migraine.severity.color)
                        levelChip(migraine.stressLevel, systemImage: "brain.head.profile", tint: .indigo)
                    }
                }

                HStack(spacing: Brand.Space.sm) {
                    if migraine.isOngoing {
                        durationLabel
                    } else if let duration = migraine.duration {
                        Label(MigraineDates.compactDurationString(duration), systemImage: "clock")
                            .labelStyle(.titleAndIcon)
                    }
                    if migraine.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityLabel(Text("Pinned"))
                    }
                    let triggerCount = migraine.triggers.count + migraine.customTriggers.count
                    if triggerCount > 0 {
                        Label("\(triggerCount)", systemImage: "exclamationmark.triangle")
                            .accessibilityLabel(Text("\(triggerCount) triggers"))
                    }
                    if let note = migraine.note, !note.isEmpty {
                        Text(note)
                            .italic()
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minHeight: 16)
            }
        }
        .padding(.vertical, Brand.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Pieces

    @ContentBuilder
    private var severityBar: some View {
        if migraine.isOngoing {
            TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { context in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(pulseColor(at: context.date))
                    .frame(width: 6)
            }
            .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(migraine.severity.color.gradient)
                .frame(width: 6)
                .accessibilityHidden(true)
        }
    }

    private func levelChip(_ value: Int, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(value, format: .number)
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.14)))
        .accessibilityHidden(true)
    }

    private var durationLabel: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            Label(MigraineDates.durationString(context.date.timeIntervalSince(migraine.startDate)), systemImage: "clock.fill")
                .monospacedDigit()
                .foregroundStyle(.mygraBlue)
                .contentTransition(.numericText())
        }
    }

    /// A color that pulses between clear and purple using a sine wave.
    private func pulseColor(at time: Date, pulseDuration: Double = 1.5) -> Color {
        let t = time.timeIntervalSinceReferenceDate / pulseDuration
        let phase = (sin(t * .pi * 2) + 1) / 2
        return Color.mygraPurple.opacity(0.35 + 0.65 * phase)
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
        if migraine.isPinned { parts.append(String(localized: "Pinned")) }
        let triggerCount = migraine.triggers.count + migraine.customTriggers.count
        if triggerCount > 0 {
            parts.append(String(localized: "Triggers \(triggerCount)"))
        }
        if let note = migraine.note, !note.isEmpty {
            parts.append(String(localized: "Note \(note)"))
        }
        return parts.joined(separator: ", ")
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
