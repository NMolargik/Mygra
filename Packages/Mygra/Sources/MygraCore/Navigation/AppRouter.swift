//
//  AppRouter.swift
//  MygraCore
//
//  App-wide navigation state: the selected tab and the deep link waiting to be acted
//  on. Widgets, quick actions, Siri, the menu bar, and `onOpenURL` all funnel through
//  `open(_:)`; `MainView` observes and consumes `pendingDeepLink`. Pure Observation, so
//  routing rules are host-tested.
//

import Foundation
import Observation

@MainActor
@Observable
public final class AppRouter {
    /// The currently selected tab in the adaptive `TabView`.
    public var selectedTab: AppTab = .dashboard

    /// A deep link awaiting handling by the main UI (e.g. "open the entry form").
    /// Set by widgets / quick actions / Siri / commands; cleared once consumed.
    public var pendingDeepLink: DeepLink?

    public init() {}

    /// Selects a tab directly (menu commands, keyboard shortcuts).
    public func select(_ tab: AppTab) {
        selectedTab = tab
    }

    /// Routes a deep link: jumps to its destination tab and stores it for the screen
    /// to act on (presenting the entry form, pushing a migraine, …).
    public func open(_ link: DeepLink) {
        if let tab = link.destinationTab {
            selectedTab = tab
        }
        pendingDeepLink = link
    }

    /// Parses and routes an external URL; unknown URLs are ignored.
    @discardableResult
    public func open(url: URL) -> Bool {
        guard let link = DeepLink(url: url) else { return false }
        open(link)
        return true
    }

    /// Hands back the pending link (if any) and clears it.
    public func takePendingDeepLink() -> DeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }
}
