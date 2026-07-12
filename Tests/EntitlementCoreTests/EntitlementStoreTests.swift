import EntitlementCore
import XCTest

private enum TestProduct: String, InAppProduct, CaseIterable {
    case monthly = "pro.monthly"
    case yearly = "pro.yearly"
    var id: String { rawValue }
}

@MainActor
final class EntitlementResolutionTests: XCTestCase {
    func testFreshStoreHasUnresolvedEntitlements() {
        let store = EntitlementStore(productIDs: ["pro.monthly"])
        XCTAssertFalse(store.hasResolvedEntitlements)
        XCTAssertFalse(store.hasEntitlement)
    }

    func testPreviewStoreIsResolved() {
        let store = EntitlementStore.preview()
        XCTAssertTrue(store.hasResolvedEntitlements)
    }

    func testInjectedEntitlementsResolveAndGate() {
        let store = EntitlementStore(productIDs: ["pro.monthly", "pro.yearly"])
        store._setEntitlementsForTesting(["pro.yearly"])
        XCTAssertTrue(store.hasResolvedEntitlements)
        XCTAssertTrue(store.hasEntitlement)
        XCTAssertEqual(store.purchasedProductIDs, ["pro.yearly"])
    }

    func testInjectedEmptyEntitlementsResolveWithoutGating() {
        let store = EntitlementStore(productIDs: ["pro.monthly"])
        store._setEntitlementsForTesting([])
        XCTAssertTrue(store.hasResolvedEntitlements)
        XCTAssertFalse(store.hasEntitlement)
    }
}

@MainActor
final class PerProductEntitlementTests: XCTestCase {
    func testIsPurchasedByID() {
        let store = EntitlementStore(productIDs: ["a", "b"])
        store._setEntitlementsForTesting(["a"])
        XCTAssertTrue(store.isPurchased("a"))
        XCTAssertFalse(store.isPurchased("b"))
    }

    func testIsPurchasedByInAppProduct() {
        let store = EntitlementStore(productIDs: TestProduct.allCases.map(\.id))
        store._setEntitlementsForTesting([TestProduct.monthly.id])
        XCTAssertTrue(store.isPurchased(TestProduct.monthly))
        XCTAssertFalse(store.isPurchased(TestProduct.yearly))
    }
}

@MainActor
final class InAppProductInitTests: XCTestCase {
    func testInitFromInAppProductTypePreservesCaseOrder() {
        let store = EntitlementStore(products: TestProduct.self)
        XCTAssertEqual(store.productIDs, ["pro.monthly", "pro.yearly"])
    }
}
