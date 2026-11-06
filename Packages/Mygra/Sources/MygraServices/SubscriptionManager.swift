//
//  SubscriptionManager.swift
//  MygraServices
//
//  Mygra Plus entitlement state and StoreKit 2 purchases. Conforms to Core's
//  `EntitlementProviding` so gating logic tests with a fake instead of StoreKit. Plus is
//  granted by any live Plus transaction, or permanently to early supporters who bought
//  the app while it was paid up front (`GrandfatherRule`, checked once and cached).
//

import Foundation
import Observation
import StoreKit
import MygraCore
import os

@MainActor
@Observable
public final class SubscriptionManager: EntitlementProviding {
    public private(set) var products: [Product] = []
    public private(set) var purchasedProductIDs: Set<String> = []
    public private(set) var isLoading = false
    public private(set) var error: SubscriptionError?
    /// Early-supporter status (nil until the App Store transaction has been checked).
    public private(set) var isGrandfathered: Bool?

    @ObservationIgnored private let cache: PlusEntitlementCache
    @ObservationIgnored private var transactionListener: Task<Void, Never>?

    /// Whether the user has Plus through a purchase or the early-supporter grant.
    public var hasPlus: Bool { isGrandfathered == true || hasPurchasedPlus }

    public var hasPurchasedPlus: Bool { !purchasedProductIDs.intersection(PlusProduct.productIDs).isEmpty }

    /// The purchased plan shown in Settings (lifetime wins over a lingering subscription).
    public var currentPlan: PlusProduct? {
        if purchasedProductIDs.contains(PlusProduct.lifetime.rawValue) { return .lifetime }
        return purchasedProductIDs.lazy.compactMap(PlusProduct.init(rawValue:)).first
    }

    public var lifetimeProduct: Product? { products.first { $0.id == PlusProduct.lifetime.rawValue } }

    /// Whether to show the one-time "Plus is yours for life" thank-you.
    public var shouldShowEarlySupporterThanks: Bool { cache.shouldShowEarlySupporterThanks }

    /// - Parameters:
    ///   - defaults: Where the grandfather verdict and thank-you flag are cached.
    ///   - startsAutomatically: Loads products, checks the app transaction, and listens
    ///     for transaction updates on init. Tests pass false to stay off StoreKit.
    public init(defaults: any KeyValueStoring = UserDefaults.standard, startsAutomatically: Bool = true) {
        cache = PlusEntitlementCache(defaults: defaults)
        isGrandfathered = cache.grandfathered
        guard startsAutomatically else { return }
        transactionListener = listenForTransactions()
        Task {
            await refreshGrandfatherStatus()
            await loadProducts()
            await processUnfinishedTransactions()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Products

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: PlusProduct.productIDs).sorted { $0.price < $1.price }
            error = nil
        } catch {
            Log.subscription.error("Product load failed: \(error.localizedDescription)")
            self.error = .loadFailed
        }
    }

    // MARK: - Purchase / restore

    /// Purchases a product. Returns true on success, false when cancelled or pending.
    public func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    public func restorePurchases() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            cache.clearGrandfathered()
            await refreshGrandfatherStatus()
        } catch {
            Log.subscription.error("Restore failed: \(error.localizedDescription)")
            self.error = .restoreFailed
        }
    }

    public func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
    }

    /// Finishes pending transactions so a lifetime purchase never stays invisible.
    public func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
    }

    // MARK: - Early supporters

    /// Checks the original App Store transaction once and caches the verdict. A lookup
    /// failure leaves the cache empty so the next launch tries again.
    public func refreshGrandfatherStatus() async {
        if let cached = cache.grandfathered {
            isGrandfathered = cached
            return
        }
        do {
            let transaction = try checkVerified(await AppTransaction.shared)
            let qualifies = GrandfatherRule.qualifies(
                originalAppVersion: transaction.originalAppVersion,
                isProduction: transaction.environment == .production
            )
            cache.storeGrandfathered(qualifies)
            isGrandfathered = qualifies
            Log.subscription.info("Original app version \(transaction.originalAppVersion, privacy: .public); grandfathered: \(qualifies)")
        } catch {
            Log.subscription.error("App transaction lookup failed: \(error.localizedDescription)")
            isGrandfathered = nil
        }
    }

    public func markEarlySupporterThanksShown() {
        cache.markEarlySupporterThanksShown()
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await self?.updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.verificationFailed
        case .verified(let safe): return safe
        }
    }
}

/// The user-facing subscription failures.
nonisolated public enum SubscriptionError: LocalizedError, Equatable, Sendable {
    case loadFailed
    case purchaseFailed
    case restoreFailed
    case verificationFailed

    public var errorDescription: String? {
        switch self {
        case .loadFailed: String(localized: "Plans could not be loaded. Check your connection and try again.")
        case .purchaseFailed: String(localized: "The purchase could not be completed.")
        case .restoreFailed: String(localized: "Purchases could not be restored.")
        case .verificationFailed: String(localized: "The App Store could not verify this purchase.")
        }
    }
}
