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
    static func start(for migraineID: UUID, startDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = MigraineActivityAttributes()
        let state = MigraineActivityAttributes.ContentState(migraineID: migraineID, startDate: startDate)
        do {
            _ = try Activity<MigraineActivityAttributes>.request(attributes: attributes, contentState: state, pushType: nil)
        } catch {
            print("Failed to start Migraine Live Activity: \(error)")
        }
    }

    // End the Live Activity for a given migraine ID
    static func end(for migraineID: UUID) {
        let activities = Activity<MigraineActivityAttributes>.activities
        if let activity = activities.first(where: { $0.contentState.migraineID == migraineID }) {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

