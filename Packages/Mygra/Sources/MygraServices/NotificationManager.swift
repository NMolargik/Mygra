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
public final class NotificationManager: LocalNotifying, LocalNotificationScheduling {
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

    public func sendTimeSensitive(title: String, body: String, identifier: String) async throws {
        try await send(title: title, body: body, category: .alert, identifier: identifier, timeSensitive: true)
    }

    /// Delivers a local notification one second from now.
    public func send(
        title: String,
        body: String,
        category: LocalNotificationCategory = .alert,
        identifier: String = UUID().uuidString,
        timeSensitive: Bool = false
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        if timeSensitive { content.interruptionLevel = .timeSensitive }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(underlying: error)
        }
    }

    // MARK: - LocalNotificationScheduling

    /// Schedules a quiet (no sound) notification for `fireDate`, replacing any pending
    /// request with the same identifier.
    public func schedule(title: String, body: String, identifier: String, fireDate: Date, userInfo: [String: String]) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = LocalNotificationCategory.reminder.rawValue
        content.userInfo = userInfo

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(underlying: error)
        }
    }

    public func cancel(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
