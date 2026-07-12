# PaywallKit

> App Store subscriptions, one-time purchases, and app-managed trials without a third-party SDK or a cut of every sale.

[![CI](https://github.com/slgoodrich-dev/paywall-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/slgoodrich-dev/paywall-kit/actions/workflows/ci.yml)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2017%20%7C%20macOS%2014-blue.svg)
![License MIT](https://img.shields.io/badge/license-MIT-green.svg)

PaywallKit is a thin, readable StoreKit 2 wrapper for indie iOS and macOS apps. It does the monetization plumbing every app repeats (load products, purchase, verify, restore, gate on entitlement), and nothing else.

- **Zero dependencies.** It wraps StoreKit 2, not another vendor's SDK.
- **No per-sale fee.** You already pay Apple's cut. That's the only cut.
- **~565 lines you can read in one sitting.** No black box between you and the App Store. 40 tests included.
- **Three composable products.** Import only the layer your app needs.

## What you're replacing

Reaching for a subscription SDK like RevenueCat means adding a third-party dependency, sending your purchase events through someone else's servers, and, past the free tier, paying a slice of revenue for what StoreKit 2 already does natively.

Rolling your own means re-writing the same `Transaction.updates` listener, verification dance, and entitlement cache in every app.

PaywallKit is the middle path: the boilerplate, written once, that you own and can audit line by line.

## The idea: who owns the access clock

Every paywall is one of two shapes, and the difference is **who runs the clock**:

- **Subscriptions.** Apple owns the lifecycle: auto-renew, intro trials, billing retry, grace periods. Your app reflects it.
- **One-time purchases.** The customer owns it forever. If you want a trial first, the app runs that clock itself, because Apple ships no trial for non-consumables.

PaywallKit draws that line and gives you a product for each side, plus the shared spine both stand on:

| Product | For | Adds |
|---|---|---|
| **`EntitlementCore`** | every app | product loading, purchase, StoreKit 2 verification, restore, live `Transaction.updates`, entitlement gating |
| **`SubscriptionKit`** | subscriptions | display plans, period and trial labels, automatic "Save X%" badge |
| **`PurchaseKit`** | one-time purchases | a Keychain-backed trial marker and a pure access resolver |

A subscription app takes `EntitlementCore + SubscriptionKit`. A one-time-purchase app with a trial takes `EntitlementCore + PurchaseKit`. Neither kit depends on the other.

## Install

In Xcode: **File → Add Package Dependencies…** and paste:

```
https://github.com/slgoodrich-dev/paywall-kit
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/slgoodrich-dev/paywall-kit.git", from: "1.0.0")
```

Then depend on the products you use:

```swift
.target(name: "App", dependencies: [
    .product(name: "EntitlementCore", package: "paywall-kit"),
    .product(name: "SubscriptionKit", package: "paywall-kit"), // or PurchaseKit
])
```

## Subscriptions

One store per app. Product IDs come from App Store Connect.

```swift
import SubscriptionKit

@State private var store = SubscriptionStore(productIDs: ["pro.monthly", "pro.yearly"])

// Load products (call from .task or onAppear).
await store.load()

// store.plans is ready for your UI, with automatic "Save X%" badges
// when you sell both a monthly and a yearly plan.
ForEach(store.plans) { plan in
    Text("\(plan.name): \(plan.price)")
}

// Gate content on entitlement.
if store.hasEntitlement {
    ProFeatureView()
} else {
    Button("Unlock Pro") { showPaywall = true }
}

// Purchase and restore.
await store.purchase(productID: "pro.yearly")
await store.restore()
```

Gate your first render on `hasResolvedEntitlements` so a returning customer never sees a flash of paywall while entitlements load.

## One-time purchase with an app-managed trial

Apple provides no trial for non-consumables, so the app runs the clock. `PurchaseKit` gives you a marker that survives a same-device reinstall and a pure resolver that turns it into an access state. You decide what an expired trial locks.

```swift
import EntitlementCore
import PurchaseKit

let entitlements = EntitlementStore(productIDs: ["pro.lifetime"])
await entitlements.load()

// Start (or read) the trial clock. One Keychain item, per device.
let markerStore = KeychainTrialMarkerStore(service: "com.example.app")
let marker = try markerStore.startIfAbsent(now: .now)

let access = resolveAccess(
    owned: entitlements.hasEntitlement,
    marker: marker,
    policy: TrialPolicy(length: 30),
    now: .now
)

switch access {
case .purchased:                unlockEverything()
case let .trial(daysRemaining):  showTrialBanner(daysRemaining)
case .expired:                  softLock() // you decide what .expired disables
}
```

`resolveAccess` is a pure function with a fixed, documented truth table, so it is trivial to unit test with no StoreKit or Keychain needed.

## What's in the box

### EntitlementCore

- **`EntitlementStore`**: `@Observable`, `@MainActor`. Fetches products in your ID order, purchases with StoreKit 2's built-in verification, restores, and listens to `Transaction.updates` for the app's lifetime, so a refund or a Family Sharing change updates your UI without extra wiring. Exposes `hasEntitlement` (any product) and `isPurchased(_:)` (a specific one).
- **`hasResolvedEntitlements`**: `false` until the first entitlement check finishes, so you can hold initial UI instead of flashing a paywall at a paying customer.
- **`InAppProduct`**: build a store from a type-safe enum of product IDs instead of stringly-typed literals: `EntitlementStore(products: Pro.self)`.
- **`EntitlementError`**: typed `.lastError` (`.productLoadFailed`, `.purchaseFailed`, `.verificationFailed`, `.restoreFailed`), so you branch on cases instead of matching strings.
- **`EntitlementStore.preview(purchasedProductIDs:)`**: resolved entitlement state with no App Store connection, for tests and SwiftUI previews.

### SubscriptionKit

- **`SubscriptionStore`**: wraps `EntitlementCore` and adds display `plans`, forwarding the full entitlement surface so a view binds one object. Share a core across kits with `init(core:)`.
- **`SubscriptionPlan`** is the display model: name, price, period, trial ("7-day free trial"), and an automatic "Save X%" badge when a 1-month and a 1-year plan are both present.
- **`SubscriptionStore.preview(plans:)`**: fixed plans, no App Store connection. Paywall previews render without StoreKit setup.

### PurchaseKit

- **`resolveAccess(owned:marker:policy:now:)`** maps to `.purchased` / `.trial(daysRemaining:)` / `.expired`. Calendar-free: a day is a fixed 86,400-second window from the marker, so the math is deterministic and testable.
- **`KeychainTrialMarkerStore`**: one generic-password Keychain item, per device (no iCloud sync), that survives a same-device reinstall.
- **`TrialPolicy`**: the trial length in whole days.

## Type-safe product IDs

```swift
enum Pro: String, InAppProduct, CaseIterable {
    case monthly = "pro.monthly"
    case yearly = "pro.yearly"
    var id: String { rawValue }
}

let store = SubscriptionStore(products: Pro.self)

if store.hasResolvedEntitlements, store.isPurchased(Pro.yearly) {
    ProFeatureView()
}
```

Pass StoreKit purchase options (promotional offers, `appAccountToken`) straight through:

```swift
await store.purchase(productID: "pro.yearly", options: [.appAccountToken(userID)])
```

Test offline with an Xcode StoreKit Configuration file: **File → New → File… → StoreKit Configuration File**, then select it under **Product → Scheme → Edit Scheme → Run → Options**.

## Honest limits of an app-managed trial

An app-managed trial is not tamper-proof, and PaywallKit does not pretend otherwise. A wiped-device reinstall, a system-clock rollback, or a second device each starts the trial over. The Keychain marker blocks the low-effort path (a same-device reinstall) and nothing more. This is inherent to the model: Apple offers no server-backed trial for non-consumables. It is fine for a paid indie audience. It is not a license-enforcement system, so don't ship it as one.

## Requirements

iOS 17+ / macOS 14+, Swift 5.9+. No third-party dependencies.

## Contributing

Issues and pull requests are welcome. Run `swift test` before opening a PR; the CI checks build, tests, SwiftFormat, and SwiftLint (strict).

## License

MIT. See [`LICENSE`](LICENSE).
