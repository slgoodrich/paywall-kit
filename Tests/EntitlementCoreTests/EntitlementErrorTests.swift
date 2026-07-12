import EntitlementCore
import Foundation
import XCTest

final class EntitlementErrorTests: XCTestCase {
    private struct Boom: Error, LocalizedError {
        var errorDescription: String? { "boom" }
    }

    func testVerificationFailedDescription() {
        XCTAssertEqual(
            EntitlementError.verificationFailed.errorDescription,
            "The App Store couldn't verify this purchase."
        )
    }

    func testWrappedErrorDescriptionsIncludeUnderlying() {
        XCTAssertEqual(EntitlementError.productLoadFailed(Boom()).errorDescription?.contains("boom"), true)
        XCTAssertEqual(EntitlementError.purchaseFailed(Boom()).errorDescription?.contains("boom"), true)
        XCTAssertEqual(EntitlementError.restoreFailed(Boom()).errorDescription?.contains("boom"), true)
    }
}
