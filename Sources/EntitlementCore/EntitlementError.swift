import Foundation

/// Errors surfaced through `EntitlementStore.lastError`. User cancellation and
/// pending purchases are not errors; those are reported via a `false` return.
public enum EntitlementError: Error {
    /// `Product.products(for:)` failed while loading products.
    case productLoadFailed(any Error)
    /// The purchase flow threw before completing.
    case purchaseFailed(any Error)
    /// The App Store returned a transaction that failed signature verification.
    case verificationFailed
    /// `AppStore.sync()` failed during a restore.
    case restoreFailed(any Error)
}

extension EntitlementError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .productLoadFailed(error): "Couldn't load products: \(error.localizedDescription)"
        case let .purchaseFailed(error): "Purchase failed: \(error.localizedDescription)"
        case .verificationFailed: "The App Store couldn't verify this purchase."
        case let .restoreFailed(error): "Restore failed: \(error.localizedDescription)"
        }
    }
}
