//
//  ComplicationSync.swift
//  Mygra
//
//  Created by Nick Molargik on 10/1/25.
//

import Foundation
import WatchConnectivity

@MainActor 
final class ComplicationSync: NSObject, WCSessionDelegate {
    static let shared = ComplicationSync()
    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Push updates for widgets/complications
    func pushLastMigraineStart(_ timeInterval: TimeInterval) {
        // Backwards compatibility: still send the old payload
        pushStatus(lastMigraineStart: timeInterval, hasOngoing: MigraineManager.shared?.ongoingMigraine != nil)
    }

    func pushStatus(lastMigraineStart: TimeInterval, hasOngoing: Bool) {
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        let payload: [String: Any] = [
            "lastMigraineStart": lastMigraineStart,
            "hasOngoingMigraine": hasOngoing
        ]
        WCSession.default.transferCurrentComplicationUserInfo(payload)
        try? WCSession.default.updateApplicationContext(payload)
        // Also send a live message when possible for immediate UI updates
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func pushCurrentStateToWatch() {
        let defaults = UserDefaults(suiteName: AppGroup.id)
        let ts = defaults?.double(forKey: "lastMigraineStart") ?? 0
        let ongoingFromManager = MigraineManager.shared?.ongoingMigraine != nil
        let ongoingFromDefaults = defaults?.bool(forKey: "hasOngoingMigraine") ?? false
        let hasOngoing = ongoingFromManager || ongoingFromDefaults
        pushStatus(lastMigraineStart: ts, hasOngoing: hasOngoing)
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard error == nil else { return }
        // After activation, push the current known state to the watch so it can update immediately
        pushCurrentStateToWatch()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        // If the watch becomes reachable, push the latest state for immediate updates
        if session.isReachable {
            pushCurrentStateToWatch()
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // After deactivation (e.g., switching watches), re-activate the session
        WCSession.default.activate()
    }
    #endif

    // Respond to watch status requests and end commands
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handle(message: message, replyHandler: nil)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handle(message: message, replyHandler: replyHandler)
    }

    private func handle(message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        if let request = message["request"] as? String, request == "status" {
            let defaults = UserDefaults(suiteName: AppGroup.id)
            let ts = defaults?.double(forKey: "lastMigraineStart") ?? 0
            let ongoing = MigraineManager.shared?.ongoingMigraine != nil
            let response: [String: Any] = [
                "hasOngoingMigraine": ongoing,
                "lastMigraineStart": ts
            ]
            replyHandler?(response)
            return
        }
        if let command = message["command"] as? String, command == "endMigraine" {
            if let migraine = MigraineManager.shared?.ongoingMigraine {
                MigraineManager.shared?.update(migraine) { m in
                    m.endDate = Date()
                }
                let defaults = UserDefaults(suiteName: AppGroup.id)
                defaults?.set(false, forKey: "hasOngoingMigraine")
                replyHandler?(["success": true])
                // Push updated state to the watch so UI/complications refresh promptly
                pushCurrentStateToWatch()
            } else {
                replyHandler?(["success": false])
            }
            return
        }
    }
}

