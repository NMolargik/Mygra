//
//  MigraineDetailHeaderView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct MigraineDetailHeaderView: View {
    let migraine: Migraine
    let startText: String
    let endText: String
    let durationText: String
    let isOngoing: Bool
    let endError: String?
    let onEndTap: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {            
            // Timing details
            VStack(alignment: .leading, spacing: 8) {
                MetricRowView("Start", value: startText)
                MetricRowView("End", value: endText)
                MetricRowView("Duration", value: durationText)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Stats row with compact meters
            HStack(spacing: 12) {
                StatMeter(
                    title: "Pain",
                    value: Double(migraine.painLevel) / 10.0,
                    display: "\(migraine.painLevel)/10",
                    systemImage: "bolt.circle.fill",
                    tint: migraine.severity.color
                )
                StatMeter(
                    title: "Stress",
                    value: Double(migraine.stressLevel) / 10.0,
                    display: "\(migraine.stressLevel)/10",
                    systemImage: "brain.head.profile",
                    tint: .mygraPurple
                )
            }

            // Primary action
            if isOngoing {
                Button {
                    onEndTap()
                } label: {
                    Label("End Migraine", systemImage: "stop.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .padding(.horizontal, 5)
                .adaptiveGlass(tint: .mygraBlue)
                .accessibilityIdentifier("endMigraineButton")
            }

            if let error = endError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isOngoing ? "Ongoing migraine" : "Migraine details")
    }
}

private struct StatMeter: View {
    let title: String
    let value: Double   // 0.0 ... 1.0
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

            // Progress capsule
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }
}
