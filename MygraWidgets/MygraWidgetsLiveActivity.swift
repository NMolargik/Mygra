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
        // Dynamic state for the activity
        let migraineID: UUID
        let startDate: Date
        let severity: Int // New: Add severity level (1-10) for more informative display
        let notes: String? // New: Optional short notes or triggers for context
    }
}

// MARK: - Live Activity Widget
struct MygraWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MigraineActivityAttributes.self) { context in
            // Lock screen / banner UI - Enhanced with severity indicator and subtle gradient
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile.fill")
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.pink.gradient)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ongoing Migraine")
                            .font(.headline.bold())
                        // Live timer since start
                        Text(context.state.startDate, style: .timer)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                    Text("Severity: \(context.state.severity)/10")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(severityColor(severity: context.state.severity))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                if let notes = context.state.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(LinearGradient(gradient: Gradient(colors: [.clear, .pink.opacity(0.05)]), startPoint: .top, endPoint: .bottom))
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.pink)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile.fill")
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(.pink.gradient)
                            .font(.title3)
                            .accessibilityLabel("Migraine Indicator")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mygra")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            // New: Compact severity display
                            Text("Pain: \(context.state.severity)/10")
                                .font(.caption.bold())
                                .foregroundStyle(severityColor(severity: context.state.severity))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Live timer with improved styling
                    Text(context.state.startDate, style: .timer)
                        .monospacedDigit()
                        .font(.title3)
                        .foregroundStyle(.pink)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Ongoing Migraine")
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if let notes = context.state.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                        }
                        // Deep link to end the migraine in-app
                        if let url = URL(string: "mygra://migraine/\(context.state.migraineID.uuidString)?action=end") {
                            Link(destination: url) {
                                Label("End Migraine", systemImage: "stop.circle.fill")
                                    .font(.headline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(.pink.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .tint(.pink)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } compactLeading: {
                // Compact leading - Minimal icon with subtle animation if possible (but static here)
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(.pink)
                    .font(.caption)
            } compactTrailing: {
                // Compact trailing - Timer with severity hint via color
                Text(context.state.startDate, style: .timer)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(severityColor(severity: context.state.severity))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } minimal: {
                // Minimal - Icon with severity color overlay
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(severityColor(severity: context.state.severity))
                    .font(.caption)
            }
            .widgetURL(URL(string: "mygra://migraine/\(context.state.migraineID.uuidString)")) // New: Deep link on tap
            .keylineTint(.pink.opacity(0.5))
            //.contentMargins(.all, 4, for: .) // New: Slight margins for better spacing
        }
    }
}

// MARK: - Helper Functions
private func severityColor(severity: Int) -> Color {
    switch severity {
    case 1...3: return .green
    case 4...6: return .yellow
    case 7...8: return .orange
    case 9...10: return .red
    default: return .pink
    }
}

extension MigraineActivityAttributes.ContentState {
    static var sample: MigraineActivityAttributes.ContentState {
        .init(migraineID: UUID(), startDate: Date().addingTimeInterval(-3600), severity: 7, notes: "Triggered by stress")
    }
}


#Preview("Lock Screen", as: .content, using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}
