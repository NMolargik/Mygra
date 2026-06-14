//
//  Mygra_Wrist_Widgets.swift
//  Mygra Wrist Widgets
//
//  Created by Nick Molargik on 10/1/25.
//

import WidgetKit
import SwiftUI

struct Mygra_Wrist_Widgets: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DaysSinceLastMigraineWatch", provider: WatchDaysProvider()) { entry in
            WatchDaysSinceView(entry: entry)
        }
        .configurationDisplayName("Days Since")
        .description("Days since your last migraine.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    Mygra_Wrist_Widgets()
} timeline: {
    WatchDaysSinceEntry(date: .now, daysSince: 1)
    WatchDaysSinceEntry(date: .now, daysSince: 2)
    WatchDaysSinceEntry(date: .now, daysSince: 356)
}


import WidgetKit
import SwiftUI

struct WatchDaysSinceEntry: TimelineEntry {
    let date: Date
    let daysSince: Int
}

struct WatchDaysProvider: TimelineProvider {
    func placeholder(in: Context) -> WatchDaysSinceEntry { .init(date: .now, daysSince: 0) }
    func getSnapshot(in: Context, completion: @escaping (WatchDaysSinceEntry) -> Void) {
        completion(makeEntry())
    }
    func getTimeline(in: Context, completion: @escaping (Timeline<WatchDaysSinceEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .after(nextMidnight())))
    }

    private func makeEntry() -> WatchDaysSinceEntry {
        let status = SharedMigraineStatus(defaults: UserDefaults(suiteName: AppGroup.id))
        return .init(date: .now, daysSince: MigraineDates.daysSince(status.lastMigraineStart))
    }

    private func nextMidnight() -> Date {
        MigraineDates.nextMidnight()
    }
}

struct WatchDaysSinceView: View {
    var entry: WatchDaysSinceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack { Text("\(entry.daysSince)") }
                .containerBackground(for: .widget) { Color.clear }
                .widgetLabel { Text("Days") }
        case .accessoryRectangular:
            HStack {
                Text("Migraine Free")
                Spacer()
                Text("\(entry.daysSince) \(entry.daysSince == 1 ? "day" : "days")").bold().monospacedDigit()
            }
            .containerBackground(for: .widget) { Color.clear }
        default:
            Text("\(entry.daysSince)")
                .containerBackground(for: .widget) { Color.clear }
        }
    }
}
