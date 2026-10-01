//
//  DeepLink.swift
//  MygraCore
//
//  Deep link actions triggered from widgets, App Intents, Home Screen quick actions,
//  menu-bar commands, the Live Activity, or external `mygra://` URLs. Parsing is pure
//  so it is host-tested.
//

import Foundation

nonisolated public enum DeepLink: Equatable, Sendable, Hashable {
    case newMigraine
    case home
    case calendar
    case list
    case settings
    case tags
    case migraine(UUID)
    case assistant
    case endOngoing

    /// The custom URL scheme handled by the app.
    public static let scheme = "mygra"

    /// Parses a `mygra://` URL. Supported forms:
    /// - `mygra://new-migraine`
    /// - `mygra://home`, `calendar`, `list`, `settings`, `tags`, `assistant`, `end-ongoing`
    /// - `mygra://migraine/<uuid>`
    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host() else { return nil }
        switch host {
        case "new-migraine": self = .newMigraine
        case "home": self = .home
        case "calendar": self = .calendar
        case "list": self = .list
        case "settings": self = .settings
        case "tags": self = .tags
        case "assistant": self = .assistant
        case "end-ongoing": self = .endOngoing
        case "migraine":
            guard let component = url.pathComponents.dropFirst().first,
                  let id = UUID(uuidString: component) else { return nil }
            self = .migraine(id)
        default:
            return nil
        }
    }

    /// The canonical URL that opens this destination (App Intents, shortcuts, widgets).
    public var url: URL {
        let path: String
        switch self {
        case .newMigraine: path = "new-migraine"
        case .home: path = "home"
        case .calendar: path = "calendar"
        case .list: path = "list"
        case .settings: path = "settings"
        case .tags: path = "tags"
        case .assistant: path = "assistant"
        case .endOngoing: path = "end-ongoing"
        case .migraine(let id): path = "migraine/\(id.uuidString)"
        }
        return URL(string: "\(Self.scheme)://\(path)")!
    }

    /// The tab this link lands on, or nil for links that don't change tabs (the
    /// assistant sheet, ending the ongoing migraine).
    public var destinationTab: AppTab? {
        switch self {
        case .home, .newMigraine: return .dashboard
        case .calendar: return .calendar
        case .list, .migraine: return .list
        case .settings, .tags: return .settings
        case .assistant, .endOngoing: return nil
        }
    }
}

// MARK: - App Intent hand-off

extension DeepLink {
    /// App Group key used to hand a deep link from an `openAppWhenRun` App Intent to the
    /// running app, which reads and clears it on activation.
    public static let pendingDefaultsKey = "pendingDeepLinkURL"

    /// Stores this deep link for the app to consume on next activation.
    public func storePending(in defaults: (any KeyValueStoring)?) {
        defaults?.set(url.absoluteString, forKey: Self.pendingDefaultsKey)
    }

    /// Reads and clears any pending deep link handed off by an App Intent.
    public static func takePending(from defaults: (any KeyValueStoring)?) -> DeepLink? {
        guard let raw = defaults?.string(forKey: Self.pendingDefaultsKey),
              let url = URL(string: raw) else { return nil }
        defaults?.removeObject(forKey: Self.pendingDefaultsKey)
        return DeepLink(url: url)
    }
}

// MARK: - User activities

/// `NSUserActivity` types the app publishes for Handoff / Siri on-screen awareness.
nonisolated public enum UserActivityType {
    /// The user is looking at one migraine's detail screen.
    public static let viewingMigraine = "com.molargiksoftware.Mygra.viewingMigraine"
}
