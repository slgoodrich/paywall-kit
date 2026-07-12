/// A type-safe product identifier. Conform an enum of your App Store Connect
/// product IDs and build a store straight from it:
///
/// ```swift
/// enum Pro: String, InAppProduct, CaseIterable {
///     case monthly = "pro.monthly"
///     case yearly = "pro.yearly"
///     var id: String { rawValue }
/// }
///
/// let store = EntitlementStore(products: Pro.self)
/// if store.isPurchased(Pro.yearly) { ... }
/// ```
public protocol InAppProduct {
    var id: String { get }
}

public extension EntitlementStore {
    /// Builds a store from a `CaseIterable` set of `InAppProduct` identifiers,
    /// preserving case declaration order.
    convenience init<Product>(products _: Product.Type) where Product: InAppProduct, Product: CaseIterable {
        self.init(productIDs: Product.allCases.map(\.id))
    }

    /// True when the given product is currently owned.
    func isPurchased(_ product: InAppProduct) -> Bool {
        isPurchased(product.id)
    }
}
