//
//  MedicationOveruseNotifier.swift
//  MygraServices
//
//  Posts a Time Sensitive local notification when a medication class first reaches the
//  "approaching" (8 days) or "threshold" (10/15 days) level in the rolling 30 days, once
//  per crossing (the ledger resets when use falls back). Logging and these alerts are
//  free. Pure over the `LocalNotifying` seam, host-tested with a fake. Never requests
//  permission; the alert is skipped when notifications aren't authorized.
//

import Foundation
import MygraCore
import os

@MainActor
public final class MedicationOveruseNotifier {
    private let notifications: any LocalNotifying
    private let ledger: MedicationAlertLedger
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        notifications: any LocalNotifying,
        defaults: any KeyValueStoring,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.notifications = notifications
        self.ledger = MedicationAlertLedger(defaults: defaults)
        self.calendar = calendar
        self.now = now
    }

    /// Evaluates the doses in `migraines` and notifies for newly raised levels. Returns
    /// the alerts that were delivered.
    @discardableResult
    public func checkAndNotify(migraines: [Migraine]) async -> [OveruseAlert] {
        let usage = MedicationOveruse.usage(of: MedicationOveruse.doses(in: migraines), now: now(), calendar: calendar)
        // The ledger advances even when delivery is skipped, so a denied permission
        // doesn't replay old alerts if the user enables notifications later.
        let fresh = ledger.newAlerts(from: usage)
        guard !fresh.isEmpty, await notifications.isAuthorized else { return [] }

        var delivered: [OveruseAlert] = []
        for alert in fresh {
            do {
                try await notifications.sendTimeSensitive(
                    title: alert.title,
                    body: alert.message,
                    identifier: "medication-overuse-\(alert.id)-\(alert.status.rawValue)"
                )
                delivered.append(alert)
            } catch {
                Log.app.error("Failed to send medication-overuse notification: \(error.localizedDescription)")
            }
        }
        return delivered
    }
}
