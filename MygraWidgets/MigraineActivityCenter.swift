//
//  MigraineActivityCenter.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import Foundation
import ActivityKit

enum MigraineActivityCenter {

    // Start a Live Activity for an ongoing migraine
    static func start(for migraineID: UUID, startDate: Date, severity: Int, notes: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = MigraineActivityAttributes()
        let state = MigraineActivityAttributes.ContentState(
            migraineID: migraineID,
            startDate: startDate,
            severity: severity,
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
            print("Failed to start Migraine Live Activity: \(error)")
        }
    }

    // Ensure a Live Activity exists for a given migraine ID; start one if missing (e.g., after app relaunch).
    static func ensureStarted(for migraineID: UUID, startDate: Date, severity: Int, notes: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let activities = Activity<MigraineActivityAttributes>.activities
        let matching = activities.filter { $0.content.state.migraineID == migraineID }
        if matching.isEmpty {
            start(for: migraineID, startDate: startDate, severity: severity, notes: notes)
            return
        }
        // If there are duplicates for the same migraine, keep the newest and end the rest.
        if matching.count > 1 {
            // Sort by start time if available, else by id as fallback
            let sorted = matching.sorted { a, b in
                let ad = a.content.state.startDate
                let bd = b.content.state.startDate
                return ad > bd
            }
            let toKeep = sorted.first
            let toEnd = sorted.dropFirst()
            for act in toEnd {
                Task {
                    do {
                        await act.end(nil, dismissalPolicy: .immediate)
                    } catch {
                        print("[MigraineActivityCenter] Failed to end duplicate activity: \(error)")
                    }
                }
            }
            // Optionally, we could refresh the kept one with latest content if severity/notes changed.
            if let keep = toKeep {
                let state = MigraineActivityAttributes.ContentState(
                    migraineID: migraineID,
                    startDate: startDate,
                    severity: severity,
                    notes: notes
                )
                let staleDate = Date().addingTimeInterval(5 * 60)
                let content = ActivityContent(state: state, staleDate: staleDate)
                Task {
                    do {
                        await keep.update(content)
                    } catch {
                        print("[MigraineActivityCenter] Failed to update activity: \(error)")
                    }
                }
            }
        }
    }

    // End the Live Activity for a given migraine ID
    static func end(for migraineID: UUID) {
        let activities = Activity<MigraineActivityAttributes>.activities
        if let activity = activities.first(where: { $0.content.state.migraineID == migraineID }) {
            Task {
                do {
                    await activity.end(nil, dismissalPolicy: .immediate)
                } catch {
                    print("[MigraineActivityCenter] Failed to end activity: \(error)")
                }
            }
        }
    }
}
