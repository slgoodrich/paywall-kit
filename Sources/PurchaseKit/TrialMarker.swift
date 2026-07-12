import Foundation

/// Record of when the app-managed trial started on this device.
public struct TrialMarker: Codable, Equatable, Sendable {
    public let startedAt: Date

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}

/// Persistence boundary for the trial marker. `KeychainTrialMarkerStore` is
/// the production conformance; tests may add an in-memory fake.
public protocol TrialMarkerStore: Sendable {
    /// The stored marker, or nil when no trial has started on this device.
    func read() throws -> TrialMarker?

    /// Returns the stored marker when one exists; otherwise stores and returns
    /// a new marker with `startedAt == now`. Idempotent: a second call never
    /// moves the start date.
    @discardableResult
    func startIfAbsent(now: Date) throws -> TrialMarker

    /// Removes the marker. Succeeds when no marker exists.
    func clear() throws
}

public enum TrialMarkerError: Error, Sendable {
    /// `SecItemCopyMatching` returned a failure other than `errSecItemNotFound`.
    case keychainReadFailed(status: OSStatus)
    /// `SecItemAdd` failed, or a duplicate-item retry found no readable marker.
    case keychainWriteFailed(status: OSStatus)
    /// `SecItemDelete` returned a failure other than `errSecItemNotFound`.
    case keychainDeleteFailed(status: OSStatus)
    /// `JSONEncoder` could not encode the marker.
    case markerEncodingFailed(underlying: any Error)
    /// The stored item held no data, or data that did not decode as a marker.
    case markerCorrupt(reason: String)
}
