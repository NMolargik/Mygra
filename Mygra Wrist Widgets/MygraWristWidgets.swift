//
//  MygraWristWidgets.swift
//  Mygra Wrist Widgets
//
//  Days-since complication from the App Group status the watch app caches.
//

import WidgetKit
import SwiftUI
import MygraCore

struct WatchDaysSinceEntry: TimelineEntry {
    let date: Date
    let daysSince: Int
}

struct WatchDaysProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchDaysSinceEntry {
        WatchDaysSinceEntry(date: .now, daysSince: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchDaysSinceEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchDaysSinceEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .after(MigraineDates.nextMidnight())))
    }

    private func makeEntry() -> WatchDaysSinceEntry {
        let status = SharedMigraineStatus(defaults: AppGroup.defaults)
        return WatchDaysSinceEntry(date: .now, daysSince: MigraineDates.daysSince(status.lastMigraineStart))
    }
}

struct WatchDaysSinceView: View {
    let entry: WatchDaysSinceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Text("\(entry.daysSince)")
                .containerBackground(for: .widget) { Color.clear }
                .widgetLabel { Text("Days") }
        case .accessoryRectangular:
            HStack {
                Text("Migraine Free")
                Spacer()
                Text("\(entry.daysSince) days").bold().monospacedDigit()
            }
            .containerBackground(for: .widget) { Color.clear }
        default:
            Text("\(entry.daysSince)")
                .containerBackground(for: .widget) { Color.clear }
        }
    }
}

struct MygraWristWidgets: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.daysSinceLastMigraineWatch, provider: WatchDaysProvider()) { entry in
            WatchDaysSinceView(entry: entry)
        }
        .configurationDisplayName("Days Since")
        .description("Days since your last migraine.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    MygraWristWidgets()
} timeline: {
    WatchDaysSinceEntry(date: .now, daysSince: 1)
    WatchDaysSinceEntry(date: .now, daysSince: 2)
    WatchDaysSinceEntry(date: .now, daysSince: 356)
}
