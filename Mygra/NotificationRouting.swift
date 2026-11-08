//
//  NotificationRouting.swift
//  Mygra
//
//  Routes taps on Mygra's local notifications (today: the quiet "Finish logging your
//  migraine" prompt after Attack Mode) through the same deep-link relay as Home Screen
//  quick actions. The notification's `userInfo["url"]` is a `mygra://` link.
//

import Foundation
import UserNotifications
import MygraCore

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// Taps open the app and route the embedded deep link.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: raw), DeepLink(url: url) != nil else { return }
        await MainActor.run { QuickActionRelay.shared.url = url }
    }

    /// Show banners while the app is open too; the prompt is gentle and has no sound.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
