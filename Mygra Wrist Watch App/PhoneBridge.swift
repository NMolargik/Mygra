//
//  PhoneBridge.swift
//  Mygra Wrist Watch App
//
//  Created by Nick Molargik on 10/1/25.
//

import Foundation
import WatchConnectivity
import WidgetKit

final class PhoneBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneBridge()
    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveComplicationUserInfo userInfo: [String : Any] = [:]) {
        let defaults = UserDefaults(suiteName: "group.com.molargiksoftware.Mygra")
        if let ts = userInfo["lastMigraineStart"] as? TimeInterval {
            defaults?.set(ts, forKey: "lastMigraineStart")
        }
        if let ongoing = userInfo["hasOngoingMigraine"] as? Bool {
            defaults?.set(ongoing, forKey: "hasOngoingMigraine")
        }
        // Tell the watch complication to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        let defaults = UserDefaults(suiteName: "group.com.molargiksoftware.Mygra")
        if let ts = applicationContext["lastMigraineStart"] as? TimeInterval {
            defaults?.set(ts, forKey: "lastMigraineStart")
        }
        if let ongoing = applicationContext["hasOngoingMigraine"] as? Bool {
            defaults?.set(ongoing, forKey: "hasOngoingMigraine")
        }
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .phoneDataUpdated, object: nil)
    }

    // Notify the app when phone reachability changes so UI can prompt the user
    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let installed = session.isCompanionAppInstalled
        // New combined connectivity notification
        NotificationCenter.default.post(
            name: .phoneConnectivityStatusChanged,
            object: nil,
            userInfo: [
                "reachable": reachable,
                "installed": installed
            ]
        )
        // Backward compatibility for any existing observers
        NotificationCenter.default.post(
            name: .phoneReachabilityChanged,
            object: nil,
            userInfo: [
                "reachable": reachable
            ]
        )
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Publish connectivity immediately after activation
        NotificationCenter.default.post(
            name: .phoneConnectivityStatusChanged,
            object: nil,
            userInfo: [
                "reachable": session.isReachable,
                "installed": session.isCompanionAppInstalled
            ]
        )

        // Optionally attempt to pull status if reachable; if not, iPhone should push via application context
        if error == nil {
            requestStatus { hasOngoing, lastStart in
                let defaults = UserDefaults(suiteName: "group.com.molargiksoftware.Mygra")
                if let lastStart {
                    defaults?.set(lastStart.timeIntervalSince1970, forKey: "lastMigraineStart")
                }
                defaults?.set(hasOngoing, forKey: "hasOngoingMigraine")
                WidgetCenter.shared.reloadAllTimelines()
                NotificationCenter.default.post(name: .phoneDataUpdated, object: nil)
            }
        }
    }
}

extension PhoneBridge {
    func requestStatus(completion: @escaping (_ hasOngoing: Bool, _ lastStart: Date?) -> Void) {
        guard WCSession.isSupported() else { completion(false, nil); return }
        let message: [String: Any] = ["request": "status"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message) { reply in
                let ongoing = reply["hasOngoingMigraine"] as? Bool ?? false
                let ts = reply["lastMigraineStart"] as? TimeInterval ?? 0
                let date = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
                completion(ongoing, date)
            } errorHandler: { _ in
                completion(false, nil)
            }
        } else {
            completion(false, nil)
        }
    }

    func endOngoingMigraine(completion: @escaping (_ success: Bool) -> Void) {
        guard WCSession.isSupported() else { completion(false); return }
        let message: [String: Any] = ["command": "endMigraine"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message) { reply in
                completion(reply["success"] as? Bool ?? false)
            } errorHandler: { _ in
                completion(false)
            }
        } else {
            completion(false)
        }
    }
}

extension Notification.Name {
    static let phoneReachabilityChanged = Notification.Name("PhoneBridge.reachabilityChanged")
    static let phoneConnectivityStatusChanged = Notification.Name("PhoneBridge.connectivityStatusChanged")
    static let phoneDataUpdated = Notification.Name("PhoneBridge.dataUpdated")
}
