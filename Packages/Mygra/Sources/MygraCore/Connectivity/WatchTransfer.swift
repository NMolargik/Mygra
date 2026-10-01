//
//  WatchTransfer.swift
//  MygraCore
//
//  The phone↔watch wire protocol: message keys, the requests/commands the watch sends,
//  and the reply shapes. Both the phone-side relay (MygraServices) and the watch app link
//  this one definition — the old code kept string literals in both targets.
//

import Foundation

/// Plain string constants shared with the nonisolated WatchConnectivity delegate
/// callbacks, so the enum opts out of the module's default main-actor isolation.
nonisolated public enum WatchMessageKey {
    public static let request = "request"
    public static let command = "command"
    public static let painLevel = "painLevel"
    public static let stressLevel = "stressLevel"
    public static let success = "success"
    public static let error = "error"
    public static let migraineID = "migraineID"
}

/// Read-only requests the watch makes.
nonisolated public enum WatchRequest: String, Sendable {
    case status
}

/// Mutating commands the watch sends.
nonisolated public enum WatchCommand: String, Sendable {
    case endMigraine
    case startMigraine
}

/// Error codes the phone can return to the watch.
nonisolated public enum WatchCommandError: String, Sendable {
    case alreadyOngoing
}

/// A decoded inbound watch message.
nonisolated public struct WatchMessage: Sendable, Equatable {
    public var request: WatchRequest?
    public var command: WatchCommand?
    public var painLevel: Int?
    public var stressLevel: Int?

    public init(request: WatchRequest? = nil, command: WatchCommand? = nil, painLevel: Int? = nil, stressLevel: Int? = nil) {
        self.request = request
        self.command = command
        self.painLevel = painLevel
        self.stressLevel = stressLevel
    }

    /// Extracts the Sendable fields from a raw WatchConnectivity dictionary.
    public init(payload: [String: Any]) {
        request = (payload[WatchMessageKey.request] as? String).flatMap(WatchRequest.init(rawValue:))
        command = (payload[WatchMessageKey.command] as? String).flatMap(WatchCommand.init(rawValue:))
        painLevel = payload[WatchMessageKey.painLevel] as? Int
        stressLevel = payload[WatchMessageKey.stressLevel] as? Int
    }

    /// The outbound dictionary for this message.
    public var payload: [String: Any] {
        var dictionary: [String: Any] = [:]
        if let request { dictionary[WatchMessageKey.request] = request.rawValue }
        if let command { dictionary[WatchMessageKey.command] = command.rawValue }
        if let painLevel { dictionary[WatchMessageKey.painLevel] = painLevel }
        if let stressLevel { dictionary[WatchMessageKey.stressLevel] = stressLevel }
        return dictionary
    }
}

/// The phone's reply to a command.
nonisolated public struct WatchCommandReply: Sendable, Equatable {
    public var success: Bool
    public var migraineID: UUID?
    public var error: WatchCommandError?

    public init(success: Bool, migraineID: UUID? = nil, error: WatchCommandError? = nil) {
        self.success = success
        self.migraineID = migraineID
        self.error = error
    }

    public init(payload: [String: Any]) {
        success = payload[WatchMessageKey.success] as? Bool ?? false
        migraineID = (payload[WatchMessageKey.migraineID] as? String).flatMap(UUID.init(uuidString:))
        error = (payload[WatchMessageKey.error] as? String).flatMap(WatchCommandError.init(rawValue:))
    }

    public var payload: [String: Any] {
        var dictionary: [String: Any] = [WatchMessageKey.success: success]
        if let migraineID { dictionary[WatchMessageKey.migraineID] = migraineID.uuidString }
        if let error { dictionary[WatchMessageKey.error] = error.rawValue }
        return dictionary
    }
}
