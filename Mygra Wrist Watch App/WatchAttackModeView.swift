//
//  WatchAttackModeView.swift
//  Mygra Wrist Watch App
//
//  Attack Mode on the wrist: near-black, dim warm text, big targets, no animation, no
//  images. Elapsed time, five intensity steps, the usual medications, and End Attack.
//  Every action is a command to the phone, which owns the data; nothing else is asked.
//

import SwiftUI
import MygraCore

private extension Color {
    init(_ token: AttackRGB) {
        self.init(.sRGB, red: token.red, green: token.green, blue: token.blue, opacity: 1)
    }
}

private struct WatchBlockButtonStyle: ButtonStyle {
    var isSelected = false
    var isDestructive = false
    var minHeight: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        let highlighted = isSelected || configuration.isPressed
        configuration.label
            .foregroundStyle(Color(isDestructive ? AttackPalette.endText : AttackPalette.primaryText))
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                Color(highlighted ? AttackPalette.buttonFillSelected : (isDestructive ? AttackPalette.endFill : AttackPalette.buttonFill)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(AttackPalette.border), lineWidth: 1)
            )
            .transaction { $0.animation = nil }
    }
}

struct WatchAttackModeView: View {
    @Environment(PhoneBridge.self) private var bridge

    let start: Date

    @State private var isEndArmed = false
    @State private var isWorking = false
    @State private var failure: String?
    @State private var lastMedication: String?

    private var painLevel: Int? {
        bridge.status.currentPainLevel.map(AttackIntensity.nearestLevel(to:))
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Attack in progress")
                .font(.footnote)
                .foregroundStyle(Color(AttackPalette.secondaryText))

            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(MigraineDates.compactDurationString(context.date.timeIntervalSince(start)))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(AttackPalette.primaryText))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            sectionTitle("Pain now")
            ForEach(AttackIntensity.levels, id: \.self) { level in
                Button {
                    Task { await setIntensity(level) }
                } label: {
                    HStack {
                        Text("\(level)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(AttackIntensity.label(for: level))
                            .font(.footnote)
                            .foregroundStyle(Color(AttackPalette.secondaryText))
                    }
                    .padding(.horizontal, 12)
                }
                .buttonStyle(WatchBlockButtonStyle(isSelected: painLevel == level))
                .disabled(isWorking)
            }

            sectionTitle("Took medication")
            ForEach(bridge.status.quickMedications) { medication in
                Button {
                    Task { await log(medication) }
                } label: {
                    Text(medication.label)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(WatchBlockButtonStyle(minHeight: 52))
                .disabled(isWorking)
            }
            if let lastMedication {
                Text("Logged \(lastMedication)")
                    .font(.caption2)
                    .foregroundStyle(Color(AttackPalette.secondaryText))
            }

            Button {
                if isEndArmed {
                    isEndArmed = false
                    Task { await end() }
                } else {
                    isEndArmed = true
                }
            } label: {
                Text(isEndArmed ? "Tap again to end" : "End Attack")
                    .font(.headline)
            }
            .buttonStyle(WatchBlockButtonStyle(isDestructive: true, minHeight: 56))
            .disabled(isWorking)
            .padding(.top, 6)

            if !bridge.isPhoneReachable {
                Text("iPhone not reachable")
                    .font(.caption2)
                    .foregroundStyle(Color(AttackPalette.secondaryText))
            }
            if let failure {
                Text(failure)
                    .font(.caption2)
                    .foregroundStyle(Color(AttackPalette.endText))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
        .task(id: isEndArmed) {
            guard isEndArmed else { return }
            try? await Task.sleep(for: .seconds(4))
            isEndArmed = false
        }
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote)
            .foregroundStyle(Color(AttackPalette.secondaryText))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    // MARK: - Actions

    private func setIntensity(_ level: Int) async {
        guard await run({ await bridge.setIntensity(level) }) else { return }
        var status = bridge.status
        status.currentPainLevel = level
        bridge.apply(status)
    }

    private func log(_ medication: QuickMedication) async {
        guard await run({ await bridge.logMedication(medication) }) else { return }
        lastMedication = medication.label
    }

    private func end() async {
        guard await run({ await bridge.endAttack() }) else { return }
        var status = bridge.status
        status.hasOngoingMigraine = false
        status.currentPainLevel = nil
        status.quickMedications = []
        bridge.apply(status)
        bridge.requestStatus()
    }

    /// Sends one command; surfaces a quiet message on failure.
    private func run(_ command: () async -> WatchCommandReply) async -> Bool {
        isWorking = true
        failure = nil
        defer { isWorking = false }
        let reply = await command()
        if !reply.success { failure = String(localized: "Couldn't reach your iPhone. Try again.") }
        return reply.success
    }
}
