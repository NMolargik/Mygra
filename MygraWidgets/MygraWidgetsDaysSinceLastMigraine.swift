//
//  MygraWidgetsDaysSinceLastMigraine.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation
import WidgetKit
import SwiftUI

private let WidgetAppGroupID = "group.com.molargiksoftware.Mygra"

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
        let entry = makeEntry()
        // Update again at the next local midnight to bump the count naturally.
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, second: 5), matchingPolicy: .nextTimePreservingSmallerComponents) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func makeEntry() -> DaysSinceLastMigraineEntry {
        let defaults = UserDefaults(suiteName: WidgetAppGroupID)
        let ts = defaults?.double(forKey: "lastMigraineStart") ?? 0
        let lastStart = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        let days = Self.daysSince(lastStart)
        return DaysSinceLastMigraineEntry(date: Date(), daysSince: days)
    }

    private static func daysSince(_ date: Date?) -> Int {
        guard let date else { return 0 }
        let cal = Calendar.current
        let startOfDayDate = cal.startOfDay(for: date)
        let startOfDayNow = cal.startOfDay(for: Date())
        let comps = cal.dateComponents([.day], from: startOfDayDate, to: startOfDayNow)
        return max(0, comps.day ?? 0)
    }
}

private struct DaysSinceLastMigraineView: View {
    var entry: DaysSinceLastMigraineEntry

    @Environment(\.widgetFamily) private var family

    private func encouragement(for days: Int) -> String {
        if days == 0 { return "Hang in there." }
        if days <= 2 { return "Keep it up!" }
        if days >= 14 { return "Great job!" }
        let options = [
            "Small steps add up.",
            "You're doing your best.",
            "One day at a time.",
            "Progress over perfection.",
            "You've got this."
        ]
        return options.randomElement() ?? "You've got this."
    }

    var body: some View {
        ZStack {
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
        }
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
    static let kind = "DaysSinceLastMigraine"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DaysSinceLastMigraineProvider()) { entry in
            DaysSinceLastMigraineView(entry: entry)
        }
        .configurationDisplayName("Days Since Last Migraine")
        .description("Shows how many days it has been since your last migraine.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


#Preview("Widget – Small", as: .systemSmall) {
    MygraWidgetsDaysSinceLastMigraine()
} timeline: {
    DaysSinceLastMigraineEntry(date: .now, daysSince: 0)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 3)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 14)
}

#Preview("Widget – Medium", as: .systemMedium) {
    MygraWidgetsDaysSinceLastMigraine()
} timeline: {
    DaysSinceLastMigraineEntry(date: .now, daysSince: 0)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 2)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 21)
}

