//
//  ContentView.swift
//  Mygra Wrist Watch App
//
//  Created by Nick Molargik on 10/1/25.
//

import SwiftUI
import WatchConnectivity
import Combine

struct ContentView: View {
    @State private var daysSince: Int = 0
    @State private var hasOngoing: Bool = false
    @State private var isEnding: Bool = false
    @State private var isPhoneReachable: Bool = false
    @State private var isPhoneAppInstalled: Bool = false
    @State private var lastStart: Date? = nil
    @State private var now: Date = Date()
    @State private var didSetup: Bool = false

    private let appGroupID = "group.com.molargiksoftware.Mygra"

    var body: some View {
        NavigationStack {
            Group {
                if !isPhoneAppInstalled {
                    VStack(spacing: 6) {
                        Text("Open Mygra on your iPhone")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .foregroundStyle(LinearGradient(colors: [.mygraPurple, .mygraBlue], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        Button {
                            aggressiveRefresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.footnote)
                        }
                        .foregroundStyle(.white)
                        .buttonStyle(.bordered)
                        .tint(.mygraPurple)
                    }
                    .padding(.top, 4)
                } else {
                    VStack(spacing: 8) {
                        if hasOngoing {
                            Text("Ongoing Migraine")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ongoingDurationString())
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            
                            Button {
                                endOngoing()
                            } label: {
                                Label("End Migraine", systemImage: "stop.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.mygraPurple)
                            .buttonStyle(.borderedProminent)
                            .disabled(isEnding)
                        } else {
                            Text("Days since last migraine")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(daysSince)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                    .padding(.top, 8)
                    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                        self.now = date
                    }
                }
            }
            .navigationTitle("Mygra")
            .onAppear {
                // Ensure initial setup runs once when the view first appears
                guard !didSetup else { return }
                // Load any cached values immediately for a fast first paint
                loadFromDefaults()
                // Activate connectivity and try to pull fresh state without user interaction
                aggressiveRefresh()
                // Begin observing phone reachability/install status and data updates
                observeReachability()
                didSetup = true
            }
        }
    }

    // MARK: - Actions
    private func endOngoing() {
        isEnding = true
        PhoneBridge.shared.endOngoingMigraine { success in
            DispatchQueue.main.async {
                isEnding = false
                if success {
                    // Ending the migraine means there's no longer an ongoing one
                    self.hasOngoing = false
                    // Reload from defaults in case the phone also updated the last start
                    self.loadFromDefaults()
                }
            }
        }
    }

    private func refreshFromPhone() {
        PhoneBridge.shared.requestStatus { hasOngoing, lastStart in
            DispatchQueue.main.async {
                self.hasOngoing = hasOngoing
                if let lastStart {
                    self.lastStart = lastStart
                    self.daysSince = computeDaysSince(from: lastStart)
                } else {
                    // If we couldn't get a start date from phone, fall back to defaults
                    self.loadFromDefaults()
                }
            }
        }
    }
    
    private func aggressiveRefresh() {
        // Kick WCSession again and attempt a few retries with backoff
        if WCSession.isSupported() {
            WCSession.default.activate()
            self.isPhoneAppInstalled = WCSession.default.isCompanionAppInstalled
            self.isPhoneReachable = WCSession.default.isReachable
            // Try to harvest any already received application context
            applyApplicationContextIfAvailable()
        }
        // Always try a pull
        self.refreshFromPhone()
        // Schedule retries if still not installed
        attemptRefreshRetry(remaining: 3, delay: 0.8)
    }

    private func attemptRefreshRetry(remaining: Int, delay: TimeInterval) {
        guard remaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if WCSession.isSupported() {
                let session = WCSession.default
                // Re-activate in case it wasn't yet
                session.activate()
                self.isPhoneAppInstalled = session.isCompanionAppInstalled
                self.isPhoneReachable = session.isReachable
                self.applyApplicationContextIfAvailable()
            }
            // Pull again
            self.refreshFromPhone()
            // If still not installed, try again with backoff
            if !self.isPhoneAppInstalled {
                self.attemptRefreshRetry(remaining: remaining - 1, delay: min(delay * 2, 5.0))
            }
        }
    }

    private func applyApplicationContextIfAvailable() {
        guard WCSession.isSupported() else { return }
        let ctx = WCSession.default.receivedApplicationContext
        if let ts = ctx["lastMigraineStart"] as? TimeInterval {
            let defaults = UserDefaults(suiteName: appGroupID)
            defaults?.set(ts, forKey: "lastMigraineStart")
            let last = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
            self.lastStart = last
            self.daysSince = computeDaysSince(from: last)
        }
        if let ongoing = ctx["hasOngoingMigraine"] as? Bool {
            let defaults = UserDefaults(suiteName: appGroupID)
            defaults?.set(ongoing, forKey: "hasOngoingMigraine")
            self.hasOngoing = ongoing
        }
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults(suiteName: appGroupID)
        let ts = defaults?.double(forKey: "lastMigraineStart") ?? 0
        let lastStart = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        self.lastStart = lastStart
        self.daysSince = computeDaysSince(from: lastStart)
        self.hasOngoing = defaults?.bool(forKey: "hasOngoingMigraine") ?? false
    }

    private func computeDaysSince(from date: Date?) -> Int {
        guard let d = date else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: d)
        let now = cal.startOfDay(for: Date())
        return max(0, cal.dateComponents([.day], from: start, to: now).day ?? 0)
    }
    
    private func ongoingDurationString() -> String {
        guard let start = lastStart, hasOngoing else { return "--" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .brief
        formatter.maximumUnitCount = 2
        return formatter.string(from: start, to: now) ?? "--"
    }
    
    private func observeReachability() {
        // Initialize from current session state if available
        if WCSession.isSupported() {
            let session = WCSession.default
            self.isPhoneReachable = session.isReachable
            self.isPhoneAppInstalled = session.isCompanionAppInstalled
        }

        // Observe combined connectivity changes (installed + reachable)
        NotificationCenter.default.addObserver(forName: .phoneConnectivityStatusChanged, object: nil, queue: .main) { note in
            if let reachable = note.userInfo?["reachable"] as? Bool {
                self.isPhoneReachable = reachable
            }
            if let installed = note.userInfo?["installed"] as? Bool {
                self.isPhoneAppInstalled = installed
            }
        }

        // Backward compatibility: observe legacy reachability-only notification
        NotificationCenter.default.addObserver(forName: .phoneReachabilityChanged, object: nil, queue: .main) { note in
            if let reachable = note.userInfo?["reachable"] as? Bool {
                self.isPhoneReachable = reachable
            }
        }

        // Observe data updates pushed from the phone (application context or complication info)
        NotificationCenter.default.addObserver(forName: .phoneDataUpdated, object: nil, queue: .main) { _ in
            self.loadFromDefaults()
        }
    }
}

#Preview {
    ContentView()
}

