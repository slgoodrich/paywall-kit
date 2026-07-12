// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaywallKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EntitlementCore", targets: ["EntitlementCore"]),
        .library(name: "SubscriptionKit", targets: ["SubscriptionKit"]),
        .library(name: "PurchaseKit", targets: ["PurchaseKit"]),
    ],
    targets: [
        .target(name: "EntitlementCore"),
        .target(name: "SubscriptionKit", dependencies: ["EntitlementCore"]),
        .target(name: "PurchaseKit", dependencies: ["EntitlementCore"]),
        .testTarget(name: "EntitlementCoreTests", dependencies: ["EntitlementCore"]),
        .testTarget(name: "SubscriptionKitTests", dependencies: ["SubscriptionKit"]),
        .testTarget(name: "PurchaseKitTests", dependencies: ["PurchaseKit"]),
    ],
    swiftLanguageModes: [.v6]
)
