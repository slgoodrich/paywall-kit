import EntitlementCore
@testable import SubscriptionKit
import XCTest

private enum TestProduct: String, InAppProduct, CaseIterable {
    case monthly = "pro.monthly"
    case yearly = "pro.yearly"
    var id: String { rawValue }
}

@MainActor
final class SubscriptionStoreTests: XCTestCase {
    private let plans: [SubscriptionPlan] = [
        .init(
            id: "m",
            name: "Monthly",
            price: "$9.99",
            periodLabel: "month",
            trialLabel: "7-day free trial",
            trialDays: 7
        ),
        .init(id: "y", name: "Yearly", price: "$59.99", periodLabel: "year", savingsBadge: "Save 50%"),
    ]

    func testPreviewStoreExposesFixedPlans() {
        let store = SubscriptionStore.preview(plans: plans)
        XCTAssertEqual(store.plans, plans)
        XCTAssertFalse(store.hasEntitlement)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.lastError)
    }

    func testPreviewStoreLoadIsNoOp() async {
        let store = SubscriptionStore.preview(plans: plans)
        await store.load()
        XCTAssertEqual(store.plans, plans)
        XCTAssertNil(store.lastError)
    }

    func testLoadWithoutProductIDsIsNoOp() async {
        let store = SubscriptionStore(productIDs: [])
        await store.load()
        XCTAssertTrue(store.plans.isEmpty)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.lastError)
    }

    func testPurchaseUnknownProductFails() async {
        let store = SubscriptionStore.preview(plans: plans)
        let success = await store.purchase(productID: "m")
        XCTAssertFalse(success, "preview stores have no products, so purchase must be a no-op")
        XCTAssertFalse(store.hasEntitlement)
    }

    func testPurchaseWithOptionsUnknownProductFails() async {
        let store = SubscriptionStore.preview(plans: [])
        let succeeded = await store.purchase(productID: "nope", options: [])
        XCTAssertFalse(succeeded)
    }

    func testInitFromInAppProductTypePreservesCaseOrder() {
        let store = SubscriptionStore(products: TestProduct.self)
        XCTAssertEqual(store.productIDs, ["pro.monthly", "pro.yearly"])
    }

    func testEntitlementStateForwardsFromCore() {
        let store = SubscriptionStore(products: TestProduct.self)
        store._setEntitlementsForTesting([TestProduct.monthly.id])
        XCTAssertTrue(store.hasResolvedEntitlements)
        XCTAssertTrue(store.hasEntitlement)
        XCTAssertEqual(store.purchasedProductIDs, [TestProduct.monthly.id])
        XCTAssertTrue(store.isPurchased(TestProduct.monthly.id))
        XCTAssertTrue(store.isPurchased(TestProduct.monthly))
        XCTAssertFalse(store.isPurchased(TestProduct.yearly))
    }

    func testWrappingSharedCoreReflectsCoreState() {
        let core = EntitlementStore(productIDs: ["a", "b"])
        let store = SubscriptionStore(core: core)
        core._setEntitlementsForTesting(["b"])
        XCTAssertTrue(store.hasEntitlement)
        XCTAssertEqual(store.purchasedProductIDs, ["b"])
        XCTAssertTrue(store.isPurchased("b"))
        XCTAssertFalse(store.isPurchased("a"))
    }
}
