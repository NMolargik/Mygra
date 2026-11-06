//
//  ReviewMilestone.swift
//  MygraCore
//
//  When to ask for an App Store review: once on the fifth migraine ever logged, and
//  once after the first PDF report export. Each milestone fires at most once.
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

    /// Whether to prompt after a PDF export. `hasPrompted` is the persisted flag for
    /// this milestone, so the prompt fires only after the first export.
    public static func shouldPromptAfterExport(hasPrompted: Bool) -> Bool {
        !hasPrompted
    }
}
