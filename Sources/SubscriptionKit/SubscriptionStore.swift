import EntitlementCore
import Observation
import StoreKit

/// Subscription paywall store: the entitlement spine plus display plans.
@MainActor
@Observable
public final class SubscriptionStore {
    /// The underlying entitlement spine. Exposed so an app can share one core
    /// instance across kits or call core APIs directly.
    public let core: EntitlementStore

    /// Display plans built from the fetched products. Fixed plans in previews.
    public private(set) var plans: [SubscriptionPlan] = []

    public init(productIDs: [String]) {
        core = EntitlementStore(productIDs: productIDs)
    }

    public init(core: EntitlementStore) {
        self.core = core
    }

    /// A store with fixed plans and no App Store connection, for SwiftUI
    /// previews and screenshots. Purchases are no-ops.
    public static func preview(plans: [SubscriptionPlan]) -> SubscriptionStore {
        let store = SubscriptionStore(core: .preview())
        store.plans = plans
        return store
    }

    // Forwarded surface. Names and types match the core.
    public var productIDs: [String] { core.productIDs }
    public var purchasedProductIDs: Set<String> { core.purchasedProductIDs }
    public var isLoading: Bool { core.isLoading }
    public var lastError: EntitlementError? { core.lastError }
    public var hasResolvedEntitlements: Bool { core.hasResolvedEntitlements }
    public var hasEntitlement: Bool { core.hasEntitlement }

    public func isPurchased(_ productID: String) -> Bool {
        core.isPurchased(productID)
    }

    /// Fetches products and entitlements via the core, then rebuilds `plans`.
    public func load() async {
        guard !core.productIDs.isEmpty, !core.isLoading else { return }
        await core.load()
        plans = Self.makePlans(from: core.products)
    }

    @discardableResult
    public func purchase(productID: String, options: Set<Product.PurchaseOption> = []) async -> Bool {
        await core.purchase(productID: productID, options: options)
    }

    @discardableResult
    public func purchase(_ product: Product, options: Set<Product.PurchaseOption> = []) async -> Bool {
        await core.purchase(product, options: options)
    }

    public func restore() async {
        await core.restore()
    }

    public func refreshEntitlements() async {
        await core.refreshEntitlements()
    }

    static func makePlans(from products: [Product]) -> [SubscriptionPlan] {
        let yearly = products.first {
            $0.subscription?.subscriptionPeriod.unit == .year && $0.subscription?.subscriptionPeriod.value == 1
        }
        let monthly = products.first {
            $0.subscription?.subscriptionPeriod.unit == .month && $0.subscription?.subscriptionPeriod.value == 1
        }
        return products.map { product in
            var badge: String?
            if let yearly, let monthly, product.id == yearly.id,
               let percent = SubscriptionMath.savingsPercent(yearlyPrice: yearly.price, monthlyPrice: monthly.price) {
                badge = "Save \(percent)%"
            }
            return SubscriptionPlan(
                id: product.id,
                name: product.displayName,
                price: product.displayPrice,
                periodLabel: product.periodLabel,
                trialLabel: product.trialLabel,
                trialDays: product.trialDays,
                savingsBadge: badge
            )
        }
    }
}

public extension SubscriptionStore {
    /// Builds a store from a `CaseIterable` set of `InAppProduct` identifiers,
    /// preserving case declaration order.
    convenience init<P>(products _: P.Type) where P: InAppProduct, P: CaseIterable {
        self.init(productIDs: P.allCases.map(\.id))
    }

    /// True when the given product is currently owned.
    func isPurchased(_ product: InAppProduct) -> Bool {
        isPurchased(product.id)
    }
}

#if DEBUG
    public extension SubscriptionStore {
        // swiftlint:disable identifier_name
        /// Forwards to the core hook so test and preview call sites can inject
        /// entitlement state through the wrapper.
        func _setEntitlementsForTesting(_ productIDs: Set<String>) {
            core._setEntitlementsForTesting(productIDs)
        }
        // swiftlint:enable identifier_name
    }
#endif
