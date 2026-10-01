//
//  MygraWidgetsDaysSinceLastMigraine.swift
//  MygraWidgets
//
//  Days since the last migraine, from the App Group status the app keeps in sync.
//  Refreshes at local midnight so the count bumps naturally.
//

import Foundation
import WidgetKit
import SwiftUI
import MygraCore

struct DaysSinceLastMigraineEntry: TimelineEntry {
    let date: Date
    let daysSince: Int
}

private struct DaysSinceLastMigraineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysSinceLastMigraineEntry {
        DaysSinceLastMigraineEntry(date: Date(), daysSince: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysSinceLastMigraineEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysSinceLastMigraineEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .after(MigraineDates.nextMidnight())))
    }

    private func makeEntry() -> DaysSinceLastMigraineEntry {
        let status = SharedMigraineStatus(defaults: AppGroup.defaults)
        return DaysSinceLastMigraineEntry(date: Date(), daysSince: MigraineDates.daysSince(status.lastMigraineStart))
    }
}

private struct DaysSinceLastMigraineView: View {
    let entry: DaysSinceLastMigraineEntry

    @Environment(\.widgetFamily) private var family

    private func encouragement(for days: Int) -> String {
        if days == 0 { return String(localized: "Hang in there.") }
        if days <= 2 { return String(localized: "Keep it up!") }
        if days >= 14 { return String(localized: "Great job!") }
        let options = [
            String(localized: "Small steps add up."),
            String(localized: "You're doing your best."),
            String(localized: "One day at a time."),
            String(localized: "Progress over perfection."),
            String(localized: "You've got this."),
        ]
        return options.randomElement() ?? options[0]
    }

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("Days Since Last Migraine")
                .font(.caption2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineSpacing(1.5)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            Text(String(entry.daysSince))
                .font(.system(size: 56, weight: .black, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .shadow(radius: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("Days since last migraine: \(entry.daysSince)")

            if family != .systemSmall {
                Text(encouragement(for: entry.daysSince))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.mygraPurple.opacity(0.25), Color.mygraBlue.opacity(0.25)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }
}

struct MygraWidgetsDaysSinceLastMigraine: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.daysSinceLastMigraine, provider: DaysSinceLastMigraineProvider()) { entry in
            DaysSinceLastMigraineView(entry: entry)
        }
        .configurationDisplayName("Days Since Last Migraine")
        .description("Shows how many days it has been since your last migraine.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#if DEBUG
#Preview("Widget – Small", as: .systemSmall) {
    MygraWidgetsDaysSinceLastMigraine()
} timeline: {
    DaysSinceLastMigraineEntry(date: .now, daysSince: 0)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 3)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 14)
}
#endif

#if DEBUG
#Preview("Widget – Medium", as: .systemMedium) {
    MygraWidgetsDaysSinceLastMigraine()
} timeline: {
    DaysSinceLastMigraineEntry(date: .now, daysSince: 0)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 2)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 21)
}
#endif
