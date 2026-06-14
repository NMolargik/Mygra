//
//  DeepLink.swift
//  Mygra
//
//  Created by Nick Molargik on 1/20/26.
//

import Foundation

/// Deep link actions that can be triggered from widgets, App Intents,
/// menu-bar commands, or external `mygra://` URLs.
enum DeepLink: Equatable {
    case newMigraine
    case home
    case calendar
    case list
    case settings
    case migraine(UUID)
    case assistant
    case endOngoing

    /// Parses a `mygra://` URL. Supported forms:
    /// - `mygra://new-migraine`
    /// - `mygra://home`
    /// - `mygra://calendar`
    /// - `mygra://list`
    /// - `mygra://settings`
    /// - `mygra://assistant`
    /// - `mygra://migraine/<uuid>`
    init?(url: URL) {
        guard url.scheme == "mygra", let host = url.host() else { return nil }
        switch host {
        case "new-migraine":
            self = .newMigraine
        case "home":
            self = .home
        case "calendar":
            self = .calendar
        case "list":
            self = .list
        case "settings":
            self = .settings
        case "assistant":
            self = .assistant
        case "end-ongoing":
            self = .endOngoing
        case "migraine":
            let component = url.pathComponents.dropFirst().first
            guard let component, let id = UUID(uuidString: component) else { return nil }
            self = .migraine(id)
        default:
            return nil
        }
    }

    /// The canonical URL for this deep link (used by App Intents and shortcuts).
    var url: URL? {
        switch self {
        case .newMigraine: return URL(string: "mygra://new-migraine")
        case .home: return URL(string: "mygra://home")
        case .calendar: return URL(string: "mygra://calendar")
        case .list: return URL(string: "mygra://list")
        case .settings: return URL(string: "mygra://settings")
        case .assistant: return URL(string: "mygra://assistant")
        case .endOngoing: return URL(string: "mygra://end-ongoing")
        case .migraine(let id): return URL(string: "mygra://migraine/\(id.uuidString)")
        }
    }
}

// MARK: - App Intent hand-off

extension DeepLink {
    /// App Group key used to hand a deep link from an `openAppWhenRun` App
    /// Intent to the running app, which reads and clears it on activation.
    static let pendingDefaultsKey = "pendingDeepLinkURL"

    /// Stores this deep link for the app to consume on next activation.
    func storePending(in defaults: UserDefaults?) {
        defaults?.set(url?.absoluteString, forKey: Self.pendingDefaultsKey)
    }

    /// Reads and clears any pending deep link handed off by an App Intent.
    static func takePending(from defaults: UserDefaults?) -> DeepLink? {
        guard let raw = defaults?.string(forKey: Self.pendingDefaultsKey),
              let url = URL(string: raw) else { return nil }
        defaults?.removeObject(forKey: Self.pendingDefaultsKey)
        return DeepLink(url: url)
    }
}
