//
//  LiveActivityController.swift
//  MygraServices
//
//  Production `MigraineActivityControlling` over ActivityKit (iOS only).
//

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import MygraCore
import os

public struct LiveActivityController: MigraineActivityControlling {
    /// How long an update is considered fresh before the system may show it as stale.
    nonisolated private static let freshness: TimeInterval = 5 * 60

    nonisolated public init() {}

    public func ensureStarted(for migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let matching = Self.activities(for: migraineID)
        if matching.isEmpty {
            start(for: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note)
            return
        }
        // Fold duplicates: keep the newest, end the rest, refresh the kept one.
        guard matching.count > 1 else { return }
        Task.detached {
            let sorted = Self.activities(for: migraineID).sorted { $0.content.state.startDate > $1.content.state.startDate }
            for activity in sorted.dropFirst() {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if let keep = sorted.first {
                await keep.update(Self.content(migraineID: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note))
            }
        }
    }

    public func update(for migraineID: UUID, painLevel: Int, stressLevel: Int, note: String) {
        Task.detached {
            guard let activity = Self.activities(for: migraineID).first else { return }
            let startDate = activity.content.state.startDate
            await activity.update(Self.content(migraineID: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note))
        }
    }

    public func end(for migraineID: UUID) {
        Task.detached {
            for activity in Self.activities(for: migraineID) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Private

    private func start(for migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) {
        do {
            _ = try Activity<MigraineActivityAttributes>.request(
                attributes: MigraineActivityAttributes(),
                content: Self.content(migraineID: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note),
                pushType: nil
            )
        } catch {
            Log.liveActivity.error("Failed to start migraine Live Activity: \(error.localizedDescription)")
        }
    }

    nonisolated private static func activities(for migraineID: UUID) -> [Activity<MigraineActivityAttributes>] {
        Activity<MigraineActivityAttributes>.activities.filter { $0.content.state.migraineID == migraineID }
    }

    nonisolated private static func content(migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) -> ActivityContent<MigraineActivityAttributes.ContentState> {
        let state = MigraineActivityAttributes.ContentState(
            migraineID: migraineID,
            startDate: startDate,
            severity: painLevel,
            stressLevel: stressLevel,
            notes: note
        )
        return ActivityContent(state: state, staleDate: Date().addingTimeInterval(freshness))
    }
}
#endif
