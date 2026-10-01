//
//  ContentView.swift
//  Mygra Wrist Watch App
//
//  Days since the last migraine, or the ongoing timer with an End button; starts a
//  migraine on the phone when reachable.
//

import SwiftUI
import MygraCore

struct ContentView: View {
    @Environment(PhoneBridge.self) private var bridge

    @State private var isWorking = false
    @State private var syncError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if !bridge.isCompanionAppInstalled {
                    notInstalledPrompt
                } else {
                    statusContent
                }

                if let syncError {
                    Text(syncError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                }
            }
            .refreshable { refresh() }
            .navigationTitle("Mygra")
            .onAppear { refresh() }
        }
    }

    private var notInstalledPrompt: some View {
        VStack(spacing: 6) {
            Text("Open Mygra on your iPhone")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .foregroundStyle(LinearGradient(colors: [.mygraPurple, .mygraBlue], startPoint: .leading, endPoint: .trailing))
            Button {
                refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.footnote)
            }
            .foregroundStyle(.white)
            .buttonStyle(.bordered)
            .tint(.mygraPurple)
        }
        .padding(.top, 4)
    }

    private var statusContent: some View {
        VStack(spacing: 8) {
            if bridge.status.hasOngoingMigraine, let start = bridge.status.lastMigraineStart {
                Text("Ongoing Migraine")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(ongoingDuration(from: start, to: context.date))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Button {
                    Task { await endOngoing() }
                } label: {
                    Label("End Migraine", systemImage: "stop.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .tint(.mygraPurple)
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
            } else {
                Text("Days since last migraine")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(MigraineDates.daysSince(bridge.status.lastMigraineStart))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Button {
                    Task { await start() }
                } label: {
                    Label("Start Migraine", systemImage: "bolt.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || !bridge.isPhoneReachable)
                .padding(.top, 8)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func refresh() {
        syncError = nil
        bridge.refresh()
    }

    private func start() async {
        isWorking = true
        syncError = nil
        defer { isWorking = false }
        let reply = await bridge.startMigraine()
        if reply.success {
            bridge.apply(SharedMigraineStatus(lastMigraineStart: Date(), hasOngoingMigraine: true))
        } else if reply.error == .alreadyOngoing {
            syncError = String(localized: "A migraine is already ongoing.")
            bridge.requestStatus()
        } else {
            syncError = String(localized: "Couldn't start migraine. Try again.")
        }
    }

    private func endOngoing() async {
        isWorking = true
        syncError = nil
        defer { isWorking = false }
        let reply = await bridge.endOngoingMigraine()
        if reply.success {
            bridge.apply(SharedMigraineStatus(lastMigraineStart: bridge.status.lastMigraineStart, hasOngoingMigraine: false))
            bridge.requestStatus()
        } else {
            syncError = String(localized: "Couldn't end migraine. Try again.")
        }
    }

    private func ongoingDuration(from start: Date, to now: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .brief
        formatter.maximumUnitCount = 2
        return formatter.string(from: start, to: now) ?? "--"
    }
}

#Preview {
    ContentView()
        .environment(PhoneBridge.shared)
}
