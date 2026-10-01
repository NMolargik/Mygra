//
//  MigraineDetailHeaderView.swift
//  MygraFeatureMigraines
//
//  The headline card: timing rows, pain and stress meters, and (while ongoing) the
//  live elapsed time plus the single prominent End action.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

struct MigraineDetailHeaderView: View {
    let migraine: Migraine
    let startText: String
    let endText: String
    let durationText: String
    let endError: String?
    let onEndTap: () -> Void

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            if migraine.isOngoing {
                liveTimer
            }

            VStack(alignment: .leading, spacing: Brand.Space.sm) {
                MetricRowView(String(localized: "Start"), value: startText)
                MetricRowView(String(localized: "End"), value: endText)
                if !migraine.isOngoing {
                    MetricRowView(String(localized: "Duration"), value: durationText)
                }
            }
            .padding(Brand.Space.md)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))

            HStack(spacing: Brand.Space.md) {
                StatMeter(
                    title: String(localized: "Pain"),
                    value: Double(migraine.painLevel) / 10.0,
                    display: "\(migraine.painLevel)/10",
                    systemImage: "bolt.circle.fill",
                    tint: migraine.severity.color
                )
                StatMeter(
                    title: String(localized: "Stress"),
                    value: Double(migraine.stressLevel) / 10.0,
                    display: "\(migraine.stressLevel)/10",
                    systemImage: "brain.head.profile",
                    tint: .indigo
                )
            }

            if migraine.isOngoing {
                Button(action: onEndTap) {
                    Label("End Migraine", systemImage: "stop.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .primaryActionButton(tint: .mygraPurple)
                .accessibilityIdentifier("endMigraineButton")
            }

            if let endError {
                Label(endError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Brand.Space.lg)
        .cardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(migraine.isOngoing ? "Ongoing migraine" : "Migraine details")
    }

    private var liveTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: Brand.Space.xs) {
                Text(MigraineDates.elapsedString(since: migraine.startDate, now: context.date))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LinearGradient.mygraHorizontal)
                    .contentTransition(.numericText())
                Label("Elapsed", systemImage: "waveform.path.ecg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct StatMeter: View {
    let title: String
    let value: Double
    let display: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Gauge(value: value) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(tint.gradient)

            Text(display)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(Brand.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title) \(display)"))
    }
}

#Preview {
    MigraineDetailHeaderView(
        migraine: Migraine.sampleOngoing(),
        startText: "Aug 28, 2025, 3:41 PM",
        endText: "Ongoing",
        durationText: "1h 02m 09s",
        endError: nil,
        onEndTap: {}
    )
    .padding()
}
#endif
