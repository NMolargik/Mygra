//
//  MigraineDetailHeaderView.swift
//  MygraFeatureMigraines
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
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                MetricRowView(String(localized: "Start"), value: startText)
                MetricRowView(String(localized: "End"), value: endText)
                MetricRowView(String(localized: "Duration"), value: durationText)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 12) {
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
                    tint: .mygraPurple
                )
            }

            if migraine.isOngoing {
                Button(action: onEndTap) {
                    Label("End Migraine", systemImage: "stop.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .glassActionButton()
                .controlSize(.large)
                .accessibilityIdentifier("endMigraineButton")
            }

            if let endError {
                Text(endError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(secondaryBackground))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(migraine.isOngoing ? "Ongoing migraine" : "Migraine details")
    }
}

private struct StatMeter: View {
    let title: String
    let value: Double
    let display: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tint)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.quaternary)
                    .frame(height: 8)
                GeometryReader { geo in
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: max(8, min(geo.size.width * value, geo.size.width)), height: 8)
                }
                .frame(height: 8)
            }

            Text(display)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tertiaryBackground))
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
