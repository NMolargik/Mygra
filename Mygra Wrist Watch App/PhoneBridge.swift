//
//  PhoneBridge.swift
//  Mygra Wrist Watch App
//
//  The watch side of WatchConnectivity: caches the phone's pushed status in the App
//  Group (for the complication), tracks reachability, and sends the status/start/end
//  commands using the wire types from MygraCore. Delegate callbacks are nonisolated and
//  extract Sendable values before hopping to the main actor.
//

import Foundation
import Observation
import WatchConnectivity
import WidgetKit
import MygraCore

@MainActor
@Observable
final class PhoneBridge: NSObject {
    static let shared = PhoneBridge()

    /// The last known migraine status (cached in the App Group across launches).
    private(set) var status: SharedMigraineStatus
    private(set) var isPhoneReachable = false
    private(set) var isCompanionAppInstalled = false

    private override init() {
        status = SharedMigraineStatus(defaults: AppGroup.defaults)
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        refreshConnectivity()
        applyReceivedApplicationContext()
    }

    /// Re-reads reachability and any already-received application context, then asks
    /// the phone for a fresh status.
    func refresh() {
        refreshConnectivity()
        applyReceivedApplicationContext()
        requestStatus()
    }

    // MARK: - Requests

    /// Asks the phone for the current status (no-op when unreachable).
    func requestStatus() {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(WatchMessage(request: .status).payload) { reply in
            guard let status = SharedMigraineStatus(payload: reply) else { return }
            Task { @MainActor in
                PhoneBridge.shared.apply(status)
            }
        } errorHandler: { _ in }
    }

    /// Ends the ongoing migraine on the phone.
    func endOngoingMigraine() async -> WatchCommandReply {
        await send(WatchMessage(command: .endMigraine))
    }

    /// Starts a migraine on the phone with the given levels.
    func startMigraine(painLevel: Int = 5, stressLevel: Int = 5) async -> WatchCommandReply {
        await send(WatchMessage(command: .startMigraine, painLevel: painLevel, stressLevel: stressLevel))
    }

    private func send(_ message: WatchMessage) async -> WatchCommandReply {
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            return WatchCommandReply(success: false)
        }
        return await withCheckedContinuation { continuation in
            WCSession.default.sendMessage(message.payload) { reply in
                continuation.resume(returning: WatchCommandReply(payload: reply))
            } errorHandler: { _ in
                continuation.resume(returning: WatchCommandReply(success: false))
            }
        }
    }

    // MARK: - State

    private func refreshConnectivity() {
        guard WCSession.isSupported() else { return }
        isPhoneReachable = WCSession.default.isReachable
        isCompanionAppInstalled = WCSession.default.isCompanionAppInstalled
    }

    private func applyReceivedApplicationContext() {
        guard WCSession.isSupported(), let status = SharedMigraineStatus(payload: WCSession.default.receivedApplicationContext) else { return }
        apply(status)
    }

    /// Stores a status pushed by the phone and refreshes the complication.
    func apply(_ status: SharedMigraineStatus) {
        self.status = status
        status.write(to: AppGroup.defaults)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - WCSessionDelegate

extension PhoneBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let reachable = session.isReachable
        let installed = session.isCompanionAppInstalled
        Task { @MainActor in
            self.isPhoneReachable = reachable
            self.isCompanionAppInstalled = installed
            self.requestStatus()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let installed = session.isCompanionAppInstalled
        Task { @MainActor in
            self.isPhoneReachable = reachable
            self.isCompanionAppInstalled = installed
            if reachable { self.requestStatus() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveComplicationUserInfo userInfo: [String: Any] = [:]) {
        guard let status = SharedMigraineStatus(payload: userInfo) else { return }
        Task { @MainActor in self.apply(status) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let status = SharedMigraineStatus(payload: applicationContext) else { return }
        Task { @MainActor in self.apply(status) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let status = SharedMigraineStatus(payload: message) else { return }
        Task { @MainActor in self.apply(status) }
    }
}
