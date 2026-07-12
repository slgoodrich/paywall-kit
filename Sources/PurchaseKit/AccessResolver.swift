import Foundation

/// App-managed trial policy.
public struct TrialPolicy: Sendable {
    /// Trial length in whole days.
    public let length: Int

    /// - Precondition: `length >= 1`.
    public init(length: Int) {
        precondition(length >= 1, "TrialPolicy.length must be at least 1")
        self.length = length
    }
}

/// The state an app gates on. What `.expired` permits is app policy, not
/// library policy.
public enum AccessState: Equatable, Sendable {
    case purchased
    case trial(daysRemaining: Int)
    case expired
}

/// Pure resolution of the access state. `owned` comes from
/// `EntitlementStore.hasEntitlement`; `marker` from a `TrialMarkerStore`.
///
/// Day arithmetic is calendar-free: a "day" is a fixed 86,400-second window
/// measured from `marker.startedAt`. A clock rollback (negative elapsed) clamps
/// to day zero, granting the full trial again by design.
public func resolveAccess(
    owned: Bool,
    marker: TrialMarker?,
    policy: TrialPolicy,
    now: Date
) -> AccessState {
    if owned { return .purchased }
    guard let marker else { return .trial(daysRemaining: policy.length) }
    let elapsed = now.timeIntervalSince(marker.startedAt)
    let dayIndex = max(0, Int(elapsed / 86400))
    if dayIndex < policy.length {
        return .trial(daysRemaining: policy.length - dayIndex)
    }
    return .expired
}
