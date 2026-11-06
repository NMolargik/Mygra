//
//  PaywallPresenter.swift
//  MygraFeatureShared
//
//  The one place a gated feature asks for the paywall. Feature views call
//  `present(_:)` with the feature they were trying to open; the composition root
//  observes `requestedFeature` and presents `PaywallView` with that context.
//

import Foundation
import Observation
import MygraCore

/// One paywall presentation; `feature` is the gated feature that asked for it, or nil
/// when opened from Settings with no particular reason.
nonisolated public struct PaywallRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let feature: PlusFeature?

    public init(feature: PlusFeature?, id: UUID = UUID()) {
        self.feature = feature
        self.id = id
    }
}

@MainActor
@Observable
public final class PaywallPresenter {
    /// The paywall currently requested (nil when dismissed).
    public var request: PaywallRequest?

    public init() {}

    /// The feature whose paywall is showing, if any.
    public var requestedFeature: PlusFeature? { request?.feature }

    public func present(_ feature: PlusFeature? = nil) {
        request = PaywallRequest(feature: feature)
    }

    public func dismiss() {
        request = nil
    }
}
