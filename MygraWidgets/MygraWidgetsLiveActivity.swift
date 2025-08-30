//
//  MygraWidgetsLiveActivity.swift
//  MygraWidgets
//
//  Created by Nick Molargik on 8/29/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes for Migraine Live Activity
struct MigraineActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state for the activity (if we ever need to update while ongoing)
        // For our case, startDate is fixed; we keep it here to render the live timer.
        let migraineID: UUID
        let startDate: Date
    }

    // Fixed properties (none required for now)
}

// MARK: - Live Activity Widget
struct MygraWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MigraineActivityAttributes.self) { context in
            // Lock screen / banner UI
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .symbolVariant(.fill)
                    .foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ongoing Migraine")
                        .font(.headline)
                    // Live timer since start
                    Text(context.state.startDate, style: .timer)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.pink)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.heart.fill") // narrower than waveform.path.ecg
                            .foregroundStyle(.pink)
                            .accessibilityLabel("Migraine")
                        Text("Mygra")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Live timer
                    Text(context.state.startDate, style: .timer)
                        .monospacedDigit()
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Ongoing Migraine")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Deep link to end the migraine in-app
                    if let url = URL(string: "mygra://migraine/\(context.state.migraineID.uuidString)?action=end") {
                        Link(destination: url) {
                            Label("End Migraine", systemImage: "stop.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.pink)
                        .buttonStyle(.borderedProminent)
                    }
                }
            } compactLeading: {
                // Keep this minimal and narrow so the system keeps the island tight.
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.pink)
            } compactTrailing: {
                // Single view, right-aligned, minimal intrinsic width.
                Text(context.state.startDate, style: .timer)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } minimal: {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.pink)
            }
            .keylineTint(.pink)
        }
    }
}

// MARK: - Previews
extension MigraineActivityAttributes.ContentState {
    static var sample: MigraineActivityAttributes.ContentState {
        .init(migraineID: UUID(), startDate: Date().addingTimeInterval(-3600))
    }
}

#Preview("Lock Screen", as: .content, using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

