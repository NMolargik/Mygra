//
//  AppGroup.swift
//  MygraCore
//
//  App Group constants shared by the iOS app, iOS widgets, watch app, and watch widgets.
//

import Foundation

nonisolated public enum AppGroup {
    public static let id = "group.com.molargiksoftware.Mygra"

    /// The shared defaults suite, or nil when the entitlement is missing (e.g. host tests).
    public static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}
