//
//  DeepLink.swift
//  MygraCore
//
//  Deep link actions triggered from widgets, App Intents, menu-bar commands, the Live
//  Activity, or external `mygra://` URLs. Parsing is pure so it is host-tested.
//

import Foundation

nonisolated public enum DeepLink: Equatable, Sendable, Hashable {
    case newMigraine
    case home
    case calendar
    case list
    case settings
    case migraine(UUID)
    case assistant
    case endOngoing

    /// The custom URL scheme handled by the app.
    public static let scheme = "mygra"

    /// Parses a `mygra://` URL. Supported forms:
    /// - `mygra://new-migraine`
    /// - `mygra://home`, `calendar`, `list`, `settings`, `assistant`, `end-ongoing`
    /// - `mygra://migraine/<uuid>`
    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host() else { return nil }
        switch host {
        case "new-migraine": self = .newMigraine
        case "home": self = .home
        case "calendar": self = .calendar
        case "list": self = .list
        case "settings": self = .settings
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
        case .assistant: path = "assistant"
        case .endOngoing: path = "end-ongoing"
        case .migraine(let id): path = "migraine/\(id.uuidString)"
        }
        return URL(string: "\(Self.scheme)://\(path)")!
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
