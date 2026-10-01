//
//  ReviewMilestone.swift
//  MygraCore
//
//  When to ask for an App Store review: once, on the fifth migraine ever logged.
//

import Foundation

nonisolated public enum ReviewMilestone {
    /// The total migraine count that earns the (single) review prompt.
    public static let migraineCount = 5

    /// Whether the prompt should be shown now. `hasPrompted` is the persisted flag that
    /// guarantees the prompt fires at most once.
    public static func shouldPrompt(totalMigraines: Int, hasPrompted: Bool) -> Bool {
        !hasPrompted && totalMigraines == migraineCount
    }
}
