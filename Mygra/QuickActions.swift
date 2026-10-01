//
//  QuickActions.swift
//  Mygra
//
//  Home Screen quick actions (long-press the app icon). Static items are declared in
//  Info.plist with their `type` set to a `mygra://` URL, so they route through the
//  same DeepLink path as widgets, Siri, and the menu bar.
//
//  UIKit delivers quick actions only through app/scene delegates, so this file bridges
//  them into SwiftUI via a small observable relay.
//

import SwiftUI
import UIKit
import MygraCore

/// Bridge between the UIKit delegate world and SwiftUI. The `shared` instance exists
/// only because UIKit instantiates the delegates itself — this is delegate plumbing,
/// not app architecture.
@MainActor
@Observable
final class QuickActionRelay {
    static let shared = QuickActionRelay()
    var url: URL?

    init() {}
}

final class QuickActionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Cold launch from a quick action: the item arrives in the connection options
        // before any SwiftUI view exists.
        if let item = options.shortcutItem, let url = URL(string: item.type) {
            QuickActionRelay.shared.url = url
        }
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = QuickActionSceneDelegate.self
        return config
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    // Warm launch: app already running when the quick action is tapped.
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let url = URL(string: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        QuickActionRelay.shared.url = url
        completionHandler(true)
    }
}
