//
//  PhoneConnectivityManager.swift
//  MygraServices
//
//  The phone side of WatchConnectivity: pushes the shared migraine status to the watch
//  (complication user info, application context, and live messages) and services the
//  watch's status/start/end commands through use-cases. Delegate callbacks are
//  nonisolated and extract Sendable values before hopping to the main actor.
//

#if canImport(WatchConnectivity)
import Foundation
import Observation
import WatchConnectivity
import MygraCore
import os

@MainActor
@Observable
public final class PhoneConnectivityManager: NSObject, WatchStatusPushing {

    // MARK: - Public state
    public private(set) var isReachable: Bool = false
    public private(set) var isPaired: Bool = false
    public private(set) var isWatchAppInstalled: Bool = false

    // MARK: - Dependencies (injected after the graph is built)
    @ObservationIgnored private var currentStatus: (() -> SharedMigraineStatus)?
    @ObservationIgnored private var endOngoing: (any EndOngoingMigraine)?
    @ObservationIgnored private var start: (any StartMigraine)?

    @ObservationIgnored private var session: WCSession?

    public override init() {
        super.init()
    }

    /// Wires the status source and command use-cases (composition root calls this once).
    public func configure(
        currentStatus: @escaping () -> SharedMigraineStatus,
        endOngoing: any EndOngoingMigraine,
        start: any StartMigraine
    ) {
        self.currentStatus = currentStatus
        self.endOngoing = endOngoing
        self.start = start
    }

    // MARK: - Activation

    public func activate() {
        guard WCSession.isSupported() else {
            Log.watch.warning("WatchConnectivity not supported on this device")
            return
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Push

    public func pushStatus(_ status: SharedMigraineStatus) {
        guard let session, session.isPaired, session.isWatchAppInstalled else { return }
        let payload = status.payload
        session.transferCurrentComplicationUserInfo(payload)
        do {
            try session.updateApplicationContext(payload)
        } catch {
            Log.watch.error("Failed to update application context: \(error.localizedDescription)")
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Log.watch.error("Failed to send live message to watch: \(error.localizedDescription)")
            }
        }
    }

    private func pushCurrentStatus() {
        guard let currentStatus else { return }
        pushStatus(currentStatus())
    }

    // MARK: - Commands

    private func handle(_ message: WatchMessage, reply: (([String: Any]) -> Void)?) {
        if message.request == .status {
            reply?((currentStatus?() ?? .empty).payload)
            return
        }

        switch message.command {
        case .endMigraine:
            let ended = (try? endOngoing?()) ?? false
            reply?(WatchCommandReply(success: ended).payload)
            if ended { pushCurrentStatus() }

        case .startMigraine:
            guard let start else {
                reply?(WatchCommandReply(success: false).payload)
                return
            }
            let id = try? start(
                painLevel: message.painLevel ?? 5,
                stressLevel: message.stressLevel ?? 5,
                note: String(localized: "Started from Apple Watch")
            )
            if let id {
                reply?(WatchCommandReply(success: true, migraineID: id).payload)
                pushCurrentStatus()
            } else {
                reply?(WatchCommandReply(success: false, error: .alreadyOngoing).payload)
            }

        case nil:
            break
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let isPaired = session.isPaired
        let isWatchAppInstalled = session.isWatchAppInstalled
        let isReachable = session.isReachable
        let errorDescription = error?.localizedDescription
        Task { @MainActor in
            if let errorDescription {
                Log.watch.error("WatchConnectivity activation failed: \(errorDescription)")
                return
            }
            self.isPaired = isPaired
            self.isWatchAppInstalled = isWatchAppInstalled
            self.isReachable = isReachable
            self.pushCurrentStatus()
        }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.activate()
        }
    }

    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        let isPaired = session.isPaired
        let isWatchAppInstalled = session.isWatchAppInstalled
        Task { @MainActor in
            self.isPaired = isPaired
            self.isWatchAppInstalled = isWatchAppInstalled
        }
    }
    #endif

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isReachable = isReachable
            if isReachable {
                self.pushCurrentStatus()
            }
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let decoded = WatchMessage(payload: message)
        Task { @MainActor in
            self.handle(decoded, reply: nil)
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let decoded = WatchMessage(payload: message)
        // WCSession reply handlers are invoked once and are safe from any thread.
        let replyBox = UncheckedSendableBox(value: replyHandler)
        Task { @MainActor in
            self.handle(decoded, reply: replyBox.value)
        }
    }
}
#endif
