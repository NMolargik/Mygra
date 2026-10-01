//
//  UncheckedSendableBox.swift
//  MygraCore
//
//  Wraps a value that is not statically `Sendable` so it can be transferred into a
//  `Task` or across an isolation boundary under the Swift 6 language mode.
//
//  Use this only for values whose access is already serialized in practice — for
//  example a WatchConnectivity reply handler (invoked exactly once). It documents an
//  intentional, audited escape hatch rather than silencing the diagnostic at the site.
//

import Foundation

nonisolated public struct UncheckedSendableBox<Value>: @unchecked Sendable {
    public let value: Value

    public init(value: Value) {
        self.value = value
    }
}
