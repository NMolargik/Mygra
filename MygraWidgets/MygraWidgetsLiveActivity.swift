// MygraWidgetsLiveActivity.swift
// MygraWidgetsLiveActivity

import ActivityKit
import WidgetKit
import SwiftUI

struct MigraineActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
    }
    var migraineId: UUID
}

struct MigraineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MigraineActivityAttributes.self) { context in
            // Lock screen / banner UI
            VStack {
                Text("Migraine Ongoing")
                    .font(.headline)
                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                    .font(.largeTitle.monospacedDigit())
                Button("End Now") {
                    // Deep link into the app to end migraine
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .padding()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                            .font(.title.monospacedDigit())
                        Button("End") {
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } compactLeading: {
                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                    .font(.caption.monospacedDigit())
            } compactTrailing: {
                Image(systemName: "xmark.circle")
            } minimal: {
                Image(systemName: "waveform.path.ecg")
            }
        }
    }
}

// MARK: - Preview Support

extension MigraineActivityAttributes {
    static var preview: MigraineActivityAttributes {
        MigraineActivityAttributes(migraineId: UUID())
    }

    static var previewContent: MigraineActivityAttributes.ContentState {
        // Simulate a migraine started 5 minutes ago
        MigraineActivityAttributes.ContentState(startDate: Date().addingTimeInterval(-300))
    }
}

#Preview("Live Activity - Lock Screen", as: .content, using: MigraineActivityAttributes.preview) {
    MigraineLiveActivity()
} contentStates: {
    MigraineActivityAttributes.previewContent
}

#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: MigraineActivityAttributes.preview) {
    MigraineLiveActivity()
} contentStates: {
    MigraineActivityAttributes.previewContent
}

#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: MigraineActivityAttributes.preview) {
    MigraineLiveActivity()
} contentStates: {
    MigraineActivityAttributes.previewContent
}

#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: MigraineActivityAttributes.preview) {
    MigraineLiveActivity()
} contentStates: {
    MigraineActivityAttributes.previewContent
}
