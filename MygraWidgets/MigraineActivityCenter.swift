//
//  MigraineActivityCenter.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import Foundation
import ActivityKit
import os

private let logger = Logger(subsystem: "com.molargiksoftware.Mygra", category: "liveActivity")

enum MigraineActivityCenter {

    // Start a Live Activity for an ongoing migraine
    static func start(for migraineID: UUID, startDate: Date, severity: Int, stressLevel: Int, notes: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = MigraineActivityAttributes()
        let state = MigraineActivityAttributes.ContentState(
            migraineID: migraineID,
            startDate: startDate,
            severity: severity,
            stressLevel: stressLevel,
            notes: notes
        )

        // Wrap the state in ActivityContent and provide a staleDate required by current SDK
        // Choose a short freshness window; adjust as desired.
        let staleDate = Date().addingTimeInterval(5 * 60) // 5 minutes
        let content = ActivityContent(state: state, staleDate: staleDate)

        do {
            _ = try Activity<MigraineActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            logger.error("Failed to start Migraine Live Activity: \(error)")
        }
    }

    // Ensure a Live Activity exists for a given migraine ID; start one if missing (e.g., after app relaunch).
    static func ensureStarted(for migraineID: UUID, startDate: Date, severity: Int, stressLevel: Int, notes: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let matching = Activity<MigraineActivityAttributes>.activities
            .filter { $0.content.state.migraineID == migraineID }
        if matching.isEmpty {
            start(for: migraineID, startDate: startDate, severity: severity, stressLevel: stressLevel, notes: notes)
            return
        }
        // If there are duplicates for the same migraine, keep the newest and end
        // the rest, then refresh the kept one with the latest content.
        guard matching.count > 1 else { return }
        Task.detached {
            let sorted = Activity<MigraineActivityAttributes>.activities
                .filter { $0.content.state.migraineID == migraineID }
                .sorted { $0.content.state.startDate > $1.content.state.startDate }
            for act in sorted.dropFirst() {
                await act.end(nil, dismissalPolicy: .immediate)
            }
            if let keep = sorted.first {
                let state = MigraineActivityAttributes.ContentState(
                    migraineID: migraineID,
                    startDate: startDate,
                    severity: severity,
                    stressLevel: stressLevel,
                    notes: notes
                )
                let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(5 * 60))
                await keep.update(content)
            }
        }
    }

    // Update the Live Activity for a given migraine ID with new severity/notes
    static func update(for migraineID: UUID, severity: Int, stressLevel: Int, notes: String) {
        Task.detached {
            guard let activity = Activity<MigraineActivityAttributes>.activities
                .first(where: { $0.content.state.migraineID == migraineID }) else {
                return
            }
            let state = MigraineActivityAttributes.ContentState(
                migraineID: migraineID,
                startDate: activity.content.state.startDate,
                severity: severity,
                stressLevel: stressLevel,
                notes: notes
            )
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(5 * 60))
            await activity.update(content)
        }
    }

    // End the Live Activity for a given migraine ID
    static func end(for migraineID: UUID) {
        Task.detached {
            if let activity = Activity<MigraineActivityAttributes>.activities
                .first(where: { $0.content.state.migraineID == migraineID }) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
