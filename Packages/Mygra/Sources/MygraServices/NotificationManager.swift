//
//  NotificationManager.swift
//  MygraServices
//
//  Local notifications: authorization state (observable) and one-shot delivery.
//

import Foundation
import Observation
import UserNotifications
import MygraCore

nonisolated public enum LocalNotificationCategory: String, Sendable {
    case reminder
    case alert
}

nonisolated public enum NotificationError: LocalizedError {
    case authorizationRequestFailed(underlying: any Error)
    case authorizationDenied
    case schedulingFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .authorizationRequestFailed(let underlying):
            return String(localized: "Failed to request notification authorization: \(underlying.localizedDescription)")
        case .authorizationDenied:
            return String(localized: "Notifications were not allowed.")
        case .schedulingFailed(let underlying):
            return String(localized: "Failed to schedule notification: \(underlying.localizedDescription)")
        }
    }
}

@MainActor
@Observable
public final class NotificationManager: LocalNotifying {
    /// Resolved lazily: `UNUserNotificationCenter.current()` traps in processes without
    /// a bundle (host tests), and the composition root constructs this manager there.
    @ObservationIgnored private lazy var center = UNUserNotificationCenter.current()

    /// Current authorization status (refreshed by `refreshAuthorizationStatus()` at
    /// launch and after each request).
    public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    public init() {}

    public func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Requests authorization for alerts, sounds, and badges.
    public func requestAuthorization() async throws {
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            throw NotificationError.authorizationRequestFailed(underlying: error)
        }
        await refreshAuthorizationStatus()
        if !granted {
            throw NotificationError.authorizationDenied
        }
    }

    public var isAuthorized: Bool {
        get async {
            await center.notificationSettings().authorizationStatus == .authorized
        }
    }

    public func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    public func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }

    public func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    public func send(title: String, body: String, identifier: String) async throws {
        try await send(title: title, body: body, category: .alert, identifier: identifier)
    }

    /// Delivers a local notification one second from now.
    public func send(
        title: String,
        body: String,
        category: LocalNotificationCategory = .alert,
        identifier: String = UUID().uuidString
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(underlying: error)
        }
    }
}
