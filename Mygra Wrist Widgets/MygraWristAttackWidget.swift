//
//  MygraWristAttackWidget.swift
//  Mygra Wrist Widgets
//
//  The Attack Mode complication / Smart Stack entry. Tapping it opens the watch app at
//  `mygra://attack-mode`, which starts an attack when none is active and otherwise shows
//  the one in progress. While an attack is ongoing the entry carries high relevance so the
//  Smart Stack surfaces it.
//

import WidgetKit
import SwiftUI
import MygraCore

struct WatchAttackEntry: TimelineEntry {
    let date: Date
    /// Start of the ongoing attack, or nil when idle.
    let ongoingSince: Date?

    var relevance: TimelineEntryRelevance? {
        ongoingSince == nil ? nil : TimelineEntryRelevance(score: 100)
    }
}

struct WatchAttackProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchAttackEntry {
        WatchAttackEntry(date: .now, ongoingSince: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchAttackEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchAttackEntry>) -> Void) {
        // The watch app reloads all timelines whenever the phone pushes a new status.
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> WatchAttackEntry {
        let status = SharedMigraineStatus(defaults: AppGroup.defaults)
        return WatchAttackEntry(date: .now, ongoingSince: status.hasOngoingMigraine ? status.lastMigraineStart : nil)
    }
}

struct WatchAttackView: View {
    let entry: WatchAttackEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label(entry.ongoingSince == nil ? "Start Migraine" : "Attack Mode", systemImage: "moon.zzz.fill")
                        .font(.headline)
                        .widgetAccentable()
                    if let start = entry.ongoingSince {
                        Text(start, style: .timer)
                            .font(.title3.monospacedDigit())
                    } else {
                        Text("Tap to start")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .accessoryInline:
                Label(entry.ongoingSince == nil ? "Start Migraine" : "Attack Mode", systemImage: "moon.zzz.fill")
            case .accessoryCorner:
                Image(systemName: "moon.zzz.fill")
                    .widgetAccentable()
                    .widgetLabel { Text(entry.ongoingSince == nil ? "Start" : "Attack") }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .widgetAccentable()
                }
            }
        }
        .widgetURL(DeepLink.attackMode.url)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct MygraWristAttackWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.attackModeWatch, provider: WatchAttackProvider()) { entry in
            WatchAttackView(entry: entry)
        }
        .configurationDisplayName("Attack Mode")
        .description("Start a migraine and open Attack Mode.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
