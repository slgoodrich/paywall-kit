import StoreKit
@testable import SubscriptionKit
import XCTest

final class SubscriptionMathTests: XCTestCase {
    func testYearlyCheaperThanMonthly() {
        // $59.99/yr vs $9.99/mo ($119.88/yr) → 50%
        XCTAssertEqual(SubscriptionMath.savingsPercent(yearlyPrice: 59.99, monthlyPrice: 9.99), 50)
    }

    func testYearlyNotCheaper() {
        XCTAssertNil(SubscriptionMath.savingsPercent(yearlyPrice: 120, monthlyPrice: 10))
        XCTAssertNil(SubscriptionMath.savingsPercent(yearlyPrice: 130, monthlyPrice: 10))
    }

    func testSavingsRoundToNearestPercent() {
        // $79.99/yr vs $119.88/yr full price → 33.27% → 33
        XCTAssertEqual(SubscriptionMath.savingsPercent(yearlyPrice: 79.99, monthlyPrice: 9.99), 33)
    }

    func testZeroMonthlyPrice() {
        XCTAssertNil(SubscriptionMath.savingsPercent(yearlyPrice: 10, monthlyPrice: 0))
    }

    func testTrialDaysPerUnit() {
        XCTAssertEqual(SubscriptionMath.days(unit: .day, value: 3), 3)
        XCTAssertEqual(SubscriptionMath.days(unit: .week, value: 1), 7)
        XCTAssertEqual(SubscriptionMath.days(unit: .week, value: 2), 14)
        XCTAssertEqual(SubscriptionMath.days(unit: .month, value: 1), 30)
        XCTAssertEqual(SubscriptionMath.days(unit: .month, value: 6), 180)
        XCTAssertEqual(SubscriptionMath.days(unit: .year, value: 1), 365)
    }
}
