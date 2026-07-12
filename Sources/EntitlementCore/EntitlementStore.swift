import Observation
import StoreKit

/// Owns products, purchases, and the entitlement set. Create one per app and
/// share it. Knows nothing about plans or trials.
@MainActor
@Observable
public final class EntitlementStore {
    public private(set) var purchasedProductIDs: Set<String> = []
    public private(set) var isLoading = false
    public private(set) var lastError: EntitlementError?

    /// False until entitlements are resolved for the first time. Gate initial UI
    /// on this to avoid flashing a paywall at a customer who already owns access.
    public private(set) var hasResolvedEntitlements = false

    /// The product identifiers this store was configured with, in order.
    public let productIDs: [String]

    /// Products fetched by `load()`, in `productIDs` order. Empty until a fetch
    /// succeeds. SubscriptionKit builds its display plans from this.
    public private(set) var products: [Product] = []

    /// True when the user owns any of the configured products. Gate content on this.
    public var hasEntitlement: Bool { !purchasedProductIDs.isEmpty }

    /// True when the given product identifier is currently owned.
    public func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    @ObservationIgnored private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    public init(productIDs: [String]) {
        self.productIDs = productIDs
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    /// A store with no App Store connection: `load()` and both `purchase`
    /// overloads are no-ops. For SwiftUI previews and tests.
    public static func preview(purchasedProductIDs: Set<String> = []) -> EntitlementStore {
        let store = EntitlementStore(productIDs: [])
        store.purchasedProductIDs = purchasedProductIDs
        store.hasResolvedEntitlements = true
        return store
    }

    deinit { updatesTask?.cancel() }

    /// Fetches products (preserving the order of `productIDs`) and current entitlements.
    /// Safe to call again to re-fetch; concurrent calls are coalesced via `isLoading`.
    public func load() async {
        guard !productIDs.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: productIDs)
            products = productIDs.compactMap { id in fetched.first { $0.id == id } }
            await refreshEntitlements()
            lastError = nil
        } catch {
            lastError = .productLoadFailed(error)
        }
    }

    /// Returns true when the purchase succeeded and was verified.
    @discardableResult
    public func purchase(productID: String, options: Set<Product.PurchaseOption> = []) async -> Bool {
        guard let product = products.first(where: { $0.id == productID }) else { return false }
        return await purchase(product, options: options)
    }

    @discardableResult
    public func purchase(_ product: Product, options: Set<Product.PurchaseOption> = []) async -> Bool {
        do {
            switch try await product.purchase(options: options) {
            case let .success(verification):
                guard case .verified = verification else {
                    lastError = .verificationFailed
                    return false
                }
                await handle(verification)
                lastError = nil
                return purchasedProductIDs.contains(product.id)
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = .purchaseFailed(error)
            return false
        }
    }

    public func restore() async {
        do {
            try await AppStore.sync()
            lastError = nil
        } catch {
            lastError = .restoreFailed(error)
        }
        await refreshEntitlements()
    }

    public func refreshEntitlements() async {
        var owned = Set<String>()
        for await entitlement in Transaction.currentEntitlements {
            if case let .verified(transaction) = entitlement, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        purchasedProductIDs = owned
        hasResolvedEntitlements = true
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = verification else { return }
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }
        await transaction.finish()
    }
}

#if DEBUG
    public extension EntitlementStore {
        // swiftlint:disable identifier_name
        /// Test/preview hook: injects entitlement state without touching StoreKit,
        /// so gating logic can be exercised in unit tests and previews.
        func _setEntitlementsForTesting(_ productIDs: Set<String>) {
            purchasedProductIDs = productIDs
            hasResolvedEntitlements = true
        }
        // swiftlint:enable identifier_name
    }
#endif
