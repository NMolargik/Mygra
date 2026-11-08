//
//  ContentView.swift
//  Mygra Wrist Watch App
//
//  Days since the last migraine with a Start button; while an attack is active the
//  whole app is the near-dark Attack Mode (WatchAttackModeView).
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
                // An attack is active: the whole app becomes the near-dark Attack Mode.
                WatchAttackModeView(start: start)
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
        let reply = await bridge.startAttack()
        if reply.success {
            bridge.apply(SharedMigraineStatus(lastMigraineStart: Date(), hasOngoingMigraine: true, currentPainLevel: StartAttackUseCase.defaultLevel))
            bridge.requestStatus()
        } else if reply.error == .alreadyOngoing {
            syncError = String(localized: "A migraine is already ongoing.")
            bridge.requestStatus()
        } else {
            syncError = String(localized: "Couldn't start migraine. Try again.")
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environment(PhoneBridge.shared)
}
#endif
