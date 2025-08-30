//
//  MigraineRowView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct MigraineRowView: View {
    var migraine: Migraine
    var viewModel: MigraineListView.ViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Treat iPad as “regular width” even if size class is nil in this environment.
    private var isRegularWidth: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad { return true }
        return hSizeClass == .regular
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Leading status indicator
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(migraine.severity.color)
                    .frame(width: 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Primary line: start + duration, optional pin
                HStack(alignment: .firstTextBaseline) {
                    TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                        if migraine.isOngoing {
                            Text("Ongoing")
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            Text(dateRangeShort(for: migraine))
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    if migraine.pinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    // Pain and stress badges
                    HStack(spacing: 8) {
                        metricPill(
                            label: "Pain",
                            value: "\(migraine.painLevel)",
                            tint: migraine.severity.color,
                            showTextLabel: !isRegularWidth // hide label on iPad/regular width
                        )
                        metricPill(
                            label: "Stress",
                            value: "\(migraine.stressLevel)",
                            tint: .purple,
                            showTextLabel: !isRegularWidth // hide label on iPad/regular width
                        )
                    }
                }

                // Secondary line: triggers as dots + note
                HStack(spacing: 8) {
                    if migraine.triggers.count > 0 {
                        triggerDots(count: migraine.triggers.count)
                    }
                    if let note = migraine.note, !note.isEmpty {
                        Text("• \(note)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Derived strings

    private var startString: String {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yy HH:mm"
        return df.string(from: migraine.startDate)
    }

    private func dateRangeShort(for migraine: Migraine) -> String {
        if migraine.isOngoing {
            return "Ongoing"
        }
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yy HH:mm"
        let start = df.string(from: migraine.startDate)
        return "\(start)"
    }

    private func liveDurationString(now: Date) -> String {
        let end = migraine.endDate ?? now
        let s = max(0, Int(end.timeIntervalSince(migraine.startDate)))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, sec)
        } else {
            return String(format: "%dm %02ds", m, sec)
        }
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        if migraine.isOngoing {
            parts.append("Ongoing")
        } else {
            parts.append("Started \(startString)")
            if let end = migraine.endDate {
                let df = DateFormatter()
                df.dateFormat = "dd/MM/yy HH:mm"
                parts.append("Ended \(df.string(from: end))")
            }
        }
        parts.append("Pain \(migraine.painLevel)")
        parts.append("Stress \(migraine.stressLevel)")
        if migraine.triggers.count > 0 {
            parts.append("Triggers \(migraine.triggers.count)")
        }
        if let note = migraine.note, !note.isEmpty {
            parts.append("Note \(note)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - UI helpers

    private func metricPill(label: String, value: String, tint: Color, showTextLabel: Bool = true) -> some View {
        HStack(spacing: 4) {
            if showTextLabel {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.caption).bold()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    @ViewBuilder
    private func triggerDots(count: Int) -> some View {
        let limited = min(count, 10)
        HStack(spacing: 3) {
            ForEach(0..<limited, id: \.self) { _ in
                Circle()
                    .fill(.secondary)
                    .frame(width: 4, height: 4)
            }
            if count > limited {
                Text("+\(count - limited)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(count) triggers")
        .font(.caption)
    }
}

#Preview {
    MigraineRowView(
        migraine: Migraine(pinned: true, startDate: Date.now, painLevel: 7, stressLevel: 6),
        viewModel: MigraineListView.ViewModel()
    )
}

#Preview("Ongoing Migraine") {
    MigraineRowView(
        migraine: Migraine(
            pinned: false,
            startDate: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now,
            endDate: nil,
            painLevel: 8,
            stressLevel: 5,
            triggers: []),
        viewModel: MigraineListView.ViewModel()
    )
}
