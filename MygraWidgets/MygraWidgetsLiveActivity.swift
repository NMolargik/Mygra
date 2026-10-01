//
//  MygraWidgetsLiveActivity.swift
//  MygraWidgets
//
//  The ongoing-migraine Live Activity (Lock Screen, Dynamic Island, and the watchOS
//  Smart Stack). The attributes live in MygraServices and are shared with the app.
//

import ActivityKit
import WidgetKit
import SwiftUI
import MygraCore
import MygraServices

struct MygraWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MigraineActivityAttributes.self) { context in
            MigraineActivityContentView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        brainIcon
                            .font(.title3)
                            .accessibilityLabel("Migraine Indicator")
                        HStack(spacing: 6) {
                            Text("Pain: \(context.state.severity)")
                                .font(.caption.bold())
                                .foregroundStyle(severityColor(context.state.severity))
                            Text("Stress: \(context.state.stressLevel)")
                                .font(.caption.bold())
                                .foregroundStyle(stressColor)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
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
                        Link(destination: DeepLink.migraine(context.state.migraineID).url) {
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
            } compactLeading: {
                brainIcon
            } compactTrailing: {
                HStack(spacing: 2) {
                    levelChip(context.state.severity, color: severityColor(context.state.severity))
                    levelChip(context.state.stressLevel, color: stressColor)
                }
            } minimal: {
                brainIcon
                    .padding()
            }
            .widgetURL(DeepLink.migraine(context.state.migraineID).url)
            .keylineTint(.red.opacity(0.5))
        }
        .supplementalActivityFamilies([.small])
    }

    private func levelChip(_ value: Int, color: Color) -> some View {
        Text("\(value)")
            .font(.caption2.bold())
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Content view (Lock Screen / banner / watch Smart Stack)

private struct MigraineActivityContentView: View {
    let context: ActivityViewContext<MigraineActivityAttributes>
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        Group {
            if activityFamily == .small {
                smallLayout
            } else {
                fullLayout
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var smallLayout: some View {
        VStack(spacing: 5) {
            HStack {
                Text("Ongoing Migraine")
                Spacer()
            }
            .padding(.leading, 8)
            HStack(alignment: .center, spacing: 6) {
                brainIcon
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)

                Text(context.state.startDate, style: .timer)
                    .monospacedDigit()
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    levelBadge(context.state.severity, color: severityColor(context.state.severity))
                        .accessibilityLabel("Pain \(context.state.severity) out of 10")
                    levelBadge(context.state.stressLevel, color: stressColor)
                        .accessibilityLabel("Stress \(context.state.stressLevel) out of 10")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private var fullLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                brainIcon
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ongoing Migraine")
                        .font(.headline.bold())
                    Text(context.state.startDate, style: .timer)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
                HStack(spacing: 6) {
                    levelPill("Pain: \(context.state.severity)", color: severityColor(context.state.severity))
                    levelPill("Stress: \(context.state.stressLevel)", color: stressColor)
                }
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

    private func levelBadge(_ value: Int, color: Color) -> some View {
        ZStack {
            Circle().fill(color)
            Text("\(value)")
                .font(.caption2.bold())
                .monospacedDigit()
                .foregroundStyle(.black)
        }
        .frame(width: 22, height: 22)
    }

    private func levelPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(color)
            .foregroundStyle(.black)
            .clipShape(Capsule())
    }
}

// MARK: - Shared pieces

private var brainIcon: some View {
    Image(systemName: "brain.head.profile.fill")
        .symbolRenderingMode(.multicolor)
        .foregroundStyle(
            LinearGradient(colors: [Color.mygraPurple, Color.mygraBlue], startPoint: .topTrailing, endPoint: .bottomLeading)
        )
}

private func severityColor(_ severity: Int) -> Color {
    switch severity {
    case 1...3: return .green
    case 4...6: return .yellow
    case 7...8: return .orange
    default: return .red
    }
}

private let stressColor: Color = .indigo

#if DEBUG
#Preview("Lock Screen", as: .content, using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#if DEBUG
#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}
#endif

#if DEBUG
#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}
#endif
#endif
