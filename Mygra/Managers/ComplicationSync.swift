//
//  ComplicationSync.swift
//  Mygra
//
//  Created by Nick Molargik on 10/1/25.
//

import Foundation
import WatchConnectivity
import os

/// Commands the watch can send to the phone. Implemented by MigraineManager
/// and wired up at the composition root.
@MainActor
protocol WatchCommandHandling: AnyObject {
    var ongoingMigraine: Migraine? { get }
    @discardableResult func endOngoingMigraine() -> Bool
    func startMigraineFromWatch(painLevel: Int, stressLevel: Int) -> UUID?
}

@MainActor
final class ComplicationSync: NSObject, WCSessionDelegate, WatchStatusPushing {

    /// Handles watch-originated commands. Set by the composition root after
    /// the MigraineManager exists; weak to avoid a retain cycle.
    weak var commandHandler: WatchCommandHandling?

    private let sharedDefaults: KeyValueStoring?

    init(sharedDefaults: KeyValueStoring? = UserDefaults(suiteName: AppGroup.id)) {
        self.sharedDefaults = sharedDefaults
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Push updates for widgets/complications

    func pushStatus(_ status: SharedMigraineStatus) {
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        let payload: [String: Any] = [
            SharedMigraineStatus.Keys.lastMigraineStart: status.lastMigraineStart?.timeIntervalSince1970 ?? 0,
            SharedMigraineStatus.Keys.hasOngoingMigraine: status.hasOngoingMigraine
        ]
        WCSession.default.transferCurrentComplicationUserInfo(payload)
        try? WCSession.default.updateApplicationContext(payload)
        // Also send a live message when possible for immediate UI updates
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                Log.watch.error("Failed to send live message to watch: \(error.localizedDescription)")
            }
        }
    }

    private func currentStatus() -> SharedMigraineStatus {
        var status = sharedDefaults?.readSharedStatus()
            ?? SharedMigraineStatus(lastMigraineStart: nil, hasOngoingMigraine: false)
        if commandHandler?.ongoingMigraine != nil {
            status.hasOngoingMigraine = true
        }
        return status
    }

    private func pushCurrentStateToWatch() {
        pushStatus(currentStatus())
    }

    // MARK: - WCSessionDelegate
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard error == nil else { return }
        // After activation, push the current known state to the watch so it can update immediately
        Task { @MainActor in
            self.pushCurrentStateToWatch()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        // If the watch becomes reachable, push the latest state for immediate updates
        let reachable = session.isReachable
        Task { @MainActor in
            if reachable {
                self.pushCurrentStateToWatch()
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // After deactivation (e.g., switching watches), re-activate the session
        WCSession.default.activate()
    }
    #endif

    // Respond to watch status requests and start/end commands
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let payload = WatchMessage(message)
        Task { @MainActor in
            self.handle(payload, replyHandler: nil)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let payload = WatchMessage(message)
        // WatchConnectivity reply handlers are safe to invoke from any thread.
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            self.handle(payload, replyHandler: reply)
        }
    }

    /// A Sendable snapshot of the fields we read from a watch message.
    private nonisolated struct WatchMessage: Sendable {
        var request: String?
        var command: String?
        var painLevel: Int?
        var stressLevel: Int?

        init(_ message: [String: Any]) {
            request = message["request"] as? String
            command = message["command"] as? String
            painLevel = message["painLevel"] as? Int
            stressLevel = message["stressLevel"] as? Int
        }
    }

    private func handle(_ message: WatchMessage, replyHandler: (([String: Any]) -> Void)?) {
        if message.request == "status" {
            let status = currentStatus()
            replyHandler?([
                SharedMigraineStatus.Keys.hasOngoingMigraine: status.hasOngoingMigraine,
                SharedMigraineStatus.Keys.lastMigraineStart: status.lastMigraineStart?.timeIntervalSince1970 ?? 0
            ])
            return
        }

        switch message.command {
        case "endMigraine":
            let ended = commandHandler?.endOngoingMigraine() ?? false
            replyHandler?(["success": ended])
            if ended {
                // MigraineManager.refresh() updates the shared defaults; push promptly.
                pushCurrentStateToWatch()
            }

        case "startMigraine":
            guard let handler = commandHandler else {
                replyHandler?(["success": false])
                return
            }
            if let id = handler.startMigraineFromWatch(
                painLevel: message.painLevel ?? 5,
                stressLevel: message.stressLevel ?? 5
            ) {
                replyHandler?(["success": true, "migraineID": id.uuidString])
                pushCurrentStateToWatch()
            } else {
                replyHandler?(["success": false, "error": "alreadyOngoing"])
            }

        default:
            break
        }
    }
}

// MigraineManager satisfies the watch-command surface directly.
extension MigraineManager: WatchCommandHandling {}
