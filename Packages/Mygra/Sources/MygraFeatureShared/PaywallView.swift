//
//  PaywallView.swift
//  MygraFeatureShared
//
//  The Mygra Plus purchase screen, opened from a gated feature with a one-line reason:
//  the subscription group through `SubscriptionStoreView` (monthly / yearly with its
//  free trial), the lifetime purchase as its own button, restore, and the legal links.
//  Purchases go through `SubscriptionManager`; `Product` is only read for display.
//

#if os(iOS)
import SwiftUI
import StoreKit
import MygraCore
import MygraDesignSystem
import MygraServices
import os

public struct PaywallView: View {
    /// The gated feature that opened the paywall (nil from Settings).
    public let feature: PlusFeature?

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(ToastManager.self) private var toast

    @State private var isPurchasingLifetime = false
    @State private var isRestoring = false

    public static let privacyURL = URL(string: "https://molargiksoftware.com/privacy")!
    public static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    public init(feature: PlusFeature? = nil) {
        self.feature = feature
    }

    private var isBusy: Bool { isPurchasingLifetime || isRestoring }

    public var body: some View {
        NavigationStack {
            Group {
                if subscription.hasPlus {
                    alreadyPlus
                } else {
                    store
                }
            }
            .background(LinearGradient.mygraWash.ignoresSafeArea())
            .navigationTitle("Mygra Plus")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        Haptics.lightImpact()
                        dismiss()
                    }
                    .disabled(isPurchasingLifetime)
                    .accessibilityIdentifier("paywall.close")
                }
            }
        }
        .tint(.mygraPurple)
        .interactiveDismissDisabled(isPurchasingLifetime)
        .task {
            if subscription.products.isEmpty, !subscription.isLoading {
                await subscription.loadProducts()
            }
        }
    }

    // MARK: - Store

    private var store: some View {
        VStack(spacing: 0) {
            SubscriptionStoreView(productIDs: PlusProduct.subscriptionProductIDs) {
                marketing
            }
            .subscriptionStoreControlStyle(.prominentPicker)
            .subscriptionStoreButtonLabel(.multiline)
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.hidden, for: .cancellation)
            .subscriptionStorePolicyDestination(url: Self.privacyURL, for: .privacyPolicy)
            .subscriptionStorePolicyDestination(url: Self.termsURL, for: .termsOfService)
            .onInAppPurchaseCompletion { _, result in
                await handleStorePurchase(result)
            }

            lifetimeRow
                .padding(.horizontal, Brand.Space.lg)
                .padding(.bottom, Brand.Space.sm)

            legal
                .padding(.bottom, Brand.Space.md)
        }
    }

    private var marketing: some View {
        VStack(spacing: Brand.Space.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient.mygra)
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.mygraPurple.opacity(0.35), radius: 16, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(spacing: Brand.Space.xs) {
                Text("Mygra Plus")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(LinearGradient.mygraHorizontal)
                Text("Logging stays free forever. Plus adds the insight layer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let feature {
                Label(feature.paywallReason, systemImage: "lock.open.fill")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.sm)
                    .background(Color.mygraPurple.opacity(0.12), in: Capsule())
                    .accessibilityAddTraits(.isStaticText)
            }

            features
        }
        .frame(maxWidth: Brand.readableWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Brand.Space.lg)
        .padding(.top, Brand.Space.md)
    }

    private var features: some View {
        VStack(spacing: 0) {
            ForEach(Array(PlusFeature.allCases.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: Brand.Space.md) {
                    Image(systemName: item.systemImage)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(LinearGradient.mygraHorizontal)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: item == feature ? "checkmark.circle.fill" : "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.mygraBlue)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Brand.Space.sm)
                .accessibilityElement(children: .combine)
                if index < PlusFeature.allCases.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.xs)
        .cardSurface()
    }

    @ContentBuilder
    private var lifetimeRow: some View {
        if let lifetime = subscription.lifetimeProduct {
            Button {
                Haptics.mediumImpact()
                Task { await purchaseLifetime(lifetime) }
            } label: {
                HStack(spacing: Brand.Space.sm) {
                    if isPurchasingLifetime {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "infinity")
                    }
                    Text("Lifetime — \(lifetime.displayPrice) once")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .secondaryActionButton(tint: .mygraBlue)
            .disabled(isBusy)
            .accessibilityHint(Text("Buys Mygra Plus once, with no subscription"))
            .accessibilityIdentifier("paywall.lifetime")
        } else if subscription.isLoading {
            ProgressView("Loading plans…")
                .controlSize(.small)
                .font(.footnote)
        } else if let error = subscription.error {
            VStack(spacing: Brand.Space.xs) {
                Text(error.errorDescription ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Haptics.lightImpact()
                    Task { await subscription.loadProducts() }
                }
                .font(.footnote.weight(.semibold))
                .accessibilityIdentifier("paywall.retry")
            }
        }
    }

    private var legal: some View {
        VStack(spacing: Brand.Space.xs) {
            Text("Subscriptions renew automatically until cancelled in Settings. Family Sharing included.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: Brand.Space.md) {
                Link("Terms of Use", destination: Self.termsURL)
                Text("·").foregroundStyle(.tertiary)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.caption)
        }
        .padding(.horizontal, Brand.Space.lg)
    }

    // MARK: - Already Plus

    private var alreadyPlus: some View {
        VStack(spacing: Brand.Space.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient.mygraHorizontal)
                .accessibilityHidden(true)
            Text("You have Mygra Plus")
                .font(.title2.weight(.bold))
            Text(subscription.isGrandfathered == true
                 ? String(localized: "Thanks for being an early supporter — Plus is yours for life.")
                 : String(localized: "Everything is unlocked on this device. Thank you for supporting Mygra."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Done") {
                Haptics.lightImpact()
                dismiss()
            }
            .primaryActionButton()
        }
        .frame(maxWidth: Brand.readableWidth)
        .frame(maxWidth: .infinity)
        .padding(Brand.Space.xl)
    }

    // MARK: - Actions

    private func handleStorePurchase(_ result: Result<Product.PurchaseResult, any Error>) async {
        switch result {
        case .success(.success):
            await subscription.updatePurchasedProducts()
            Haptics.success()
            toast.showSuccess(String(localized: "Welcome to Mygra Plus"))
            dismiss()
        case .success:
            break
        case .failure(let error):
            Log.subscription.error("Subscription purchase failed: \(error.localizedDescription)")
            Haptics.error()
            toast.show(error: SubscriptionError.purchaseFailed)
        }
    }

    private func purchaseLifetime(_ product: Product) async {
        isPurchasingLifetime = true
        defer { isPurchasingLifetime = false }
        do {
            if try await subscription.purchase(product) {
                Haptics.success()
                toast.showSuccess(String(localized: "Welcome to Mygra Plus"))
                dismiss()
            }
        } catch {
            Log.subscription.error("Lifetime purchase failed: \(error.localizedDescription)")
            Haptics.error()
            toast.show(error: SubscriptionError.purchaseFailed)
        }
    }
}

#if DEBUG
#Preview("Paywall") {
    PaywallView(feature: .assistant)
        .previewEnvironment()
}
#endif
#endif
