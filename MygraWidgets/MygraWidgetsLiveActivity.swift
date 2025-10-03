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
            // Lock screen / banner UI
            MigraineActivityContentView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile.fill")
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.mygraPurple, Color.mygraBlue],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                            .font(.title3)
                            .accessibilityLabel("Migraine Indicator")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mygra")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("Pain: \(context.state.severity)")
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
                        .foregroundStyle(.primary)
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
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .tint(.mygraPurple)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } compactLeading: {
                // Compact leading - Minimal icon with subtle animation if possible (but static here)
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(LinearGradient(
                        colors: [Color.mygraPurple, Color.mygraBlue],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ))
            } compactTrailing: {
                // Compact trailing - Ultra-compact severity chip to avoid stretching width
                Text("\(context.state.severity)")
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(severityColor(severity: context.state.severity))
                    .clipShape(Capsule())
            } minimal: {
                // Minimal - Icon with severity color overlay
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(LinearGradient(
                        colors: [Color.mygraPurple, Color.mygraBlue],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ))
                    .padding()
            }
            .widgetURL(URL(string: "mygra://migraine/\(context.state.migraineID.uuidString)"))
            .keylineTint(.red.opacity(0.5))
        }
        .supplementalActivityFamilies([.small]) // Enables compact presentation on watchOS Smart Stack
    }
}

// MARK: - Cross-platform content view that adapts by ActivityFamily
private struct MigraineActivityContentView: View {
    let context: ActivityViewContext<MigraineActivityAttributes>
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        Group {
            if activityFamily == .small {
                // Compact layout tailored for Apple Watch Smart Stack (icon • timer • severity badge)
                
                VStack(spacing: 5) {
                    HStack {
                        Text("Ongoing Migraine")
                        
                        Spacer()
                    }
                    .padding(.leading, 8)
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "brain.head.profile.fill")
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.mygraPurple, Color.mygraBlue],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityHidden(true)
                        
                        // Timer given highest priority to avoid truncation
                        Text(context.state.startDate, style: .timer)
                            .monospacedDigit()
                            .font(.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .layoutPriority(1)
                        
                        Spacer(minLength: 4)
                        
                        // Circular severity badge to save horizontal space
                        ZStack {
                            Circle()
                                .fill(severityColor(severity: context.state.severity))
                            Text("\(context.state.severity)")
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .foregroundStyle(.black)
                        }
                        .frame(width: 22, height: 22)
                        .accessibilityLabel("Severity \(context.state.severity) out of 10")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Migraine, timer \(Text(context.state.startDate, style: .timer)), severity \(context.state.severity) out of 10")
                }
            } else {
                // iOS Lock screen / banner (original fuller layout)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile.fill")
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(LinearGradient(
                                colors: [Color.mygraPurple, Color.mygraBlue],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ))
                            .ignoresSafeArea()
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
                            .foregroundStyle(.black)
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
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Helper Functions
private func severityColor(severity: Int) -> Color {
    switch severity {
    case 1...3: return .green
    case 4...6: return .yellow
    case 7...8: return .orange
    case 9...10: return .red
    default: return .red
    }
}

#Preview("Lock Screen", as: .content, using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#if os(watchOS)
#Preview("Apple Watch – Smart Stack", as: .content, using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}
#endif

