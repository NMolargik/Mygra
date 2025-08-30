import Foundation
import UserNotifications

/// Manages local notifications for the app
enum LocalNotificationCategory: String {
    case reminder
    case alert
    // Add more categories as needed
}

@Observable
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    /// Requests authorization for local notifications.
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification authorization: \(error)")
        }
    }
    
    /// Remove all pending (scheduled but undelivered) notifications
    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    /// Remove all delivered notifications from Notification Center
    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }
    
    /// Check current authorization status (async)
    var isAuthorized: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }
    
    /// Get a list of all pending notification requests (async)
    func pendingRequests() async -> [UNNotificationRequest] {
        return await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
    
    /// Send a local notification immediately.
    func send(
        title: String,
        body: String,
        category: LocalNotificationCategory = .alert,
        identifier: String = UUID().uuidString
    ) async {
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
            print("Failed to schedule notification: \(error)")
        }
    }
}
