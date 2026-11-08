//
//  MygraWidgetsAttackMode.swift
//  MygraWidgets
//
//  The Lock Screen and Control Center entries for Attack Mode. Both open
//  `mygra://attack-mode`, which starts an attack when none is active and otherwise opens
//  the one in progress. Lock Screen widgets render in the system's own (dimmable) style;
//  the app's Attack Mode screen does the near-dark work once opened.
//

import AppIntents
import Foundation
import SwiftUI
import WidgetKit
import MygraCore

// MARK: - Lock Screen widget

struct AttackModeEntry: TimelineEntry {
    let date: Date
    /// Start of the ongoing attack, or nil when idle.
    let ongoingSince: Date?
}

private struct AttackModeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AttackModeEntry {
        AttackModeEntry(date: .now, ongoingSince: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (AttackModeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttackModeEntry>) -> Void) {
        // The app reloads this kind whenever an attack starts or ends.
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> AttackModeEntry {
        let status = SharedMigraineStatus(defaults: AppGroup.defaults)
        return AttackModeEntry(date: .now, ongoingSince: status.hasOngoingMigraine ? status.lastMigraineStart : nil)
    }
}

private struct AttackModeWidgetView: View {
    let entry: AttackModeEntry
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
                        Text("One tap, almost no light")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .accessoryInline:
                if let start = entry.ongoingSince {
                    Label {
                        Text(start, style: .timer)
                    } icon: {
                        Image(systemName: "moon.zzz.fill")
                    }
                } else {
                    Label("Start Migraine", systemImage: "moon.zzz.fill")
                }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.title3)
                            .widgetAccentable()
                        Text(entry.ongoingSince == nil ? "Start" : "Attack")
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
        }
        .widgetURL(DeepLink.attackMode.url)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct MygraWidgetsAttackMode: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.attackMode, provider: AttackModeProvider()) { entry in
            AttackModeWidgetView(entry: entry)
        }
        .configurationDisplayName("Attack Mode")
        .description("Start a migraine or reopen Attack Mode from the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Control Center control

/// iOS 18 Control Center / Lock Screen control. Opens the app to `mygra://attack-mode`.
struct MygraAttackModeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WidgetKind.attackModeControl) {
            ControlWidgetButton(action: OpenURLIntent(DeepLink.attackMode.url)) {
                Label("Start Migraine", systemImage: "moon.zzz.fill")
            }
        }
        .displayName("Start Migraine")
        .description("Starts a migraine and opens Attack Mode.")
    }
}
