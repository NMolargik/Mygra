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
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                if isOngoing {
                    Text("Ongoing Migraine")
                        .font(.title2).bold()
                }
                Spacer()
            }
            
            HStack(spacing: 12) {
                InfoPillView(
                    title: "Pain",
                    value: "\(migraine.painLevel)",
                    icon: "face.dashed",
                    tint: migraine.severity.color
                )
                InfoPillView(
                    title: "Stress",
                    value: "\(migraine.stressLevel)",
                    icon: "brain.head.profile",
                    tint: .purple
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                LabeledRow("Start", value: startText)
                LabeledRow("End", value: endText)
                LabeledRow("Duration", value: durationText)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            if isOngoing {
                Button {
                    onEndTap()
                } label: {
                    Label("End Migraine", systemImage: "stop.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
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
    }
}
