import Foundation
import PurchaseKit
import XCTest

final class AccessResolverTests: XCTestCase {
    private let policy = TrialPolicy(length: 30)
    private let startedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private var marker: TrialMarker { TrialMarker(startedAt: startedAt) }
    private func at(_ elapsed: TimeInterval) -> Date {
        startedAt.addingTimeInterval(elapsed)
    }

    func testOwnedWinsWithNoMarker() {
        XCTAssertEqual(resolveAccess(owned: true, marker: nil, policy: policy, now: at(0)), .purchased)
    }

    func testOwnedWinsDuringTrial() {
        XCTAssertEqual(resolveAccess(owned: true, marker: marker, policy: policy, now: at(86400)), .purchased)
    }

    func testOwnedWinsAfterExpiry() {
        XCTAssertEqual(resolveAccess(owned: true, marker: marker, policy: policy, now: at(2_592_000)), .purchased)
    }

    func testNoMarkerResolvesFullTrial() {
        XCTAssertEqual(
            resolveAccess(owned: false, marker: nil, policy: policy, now: at(0)),
            .trial(daysRemaining: 30)
        )
    }

    func testStartInstantIsDayZero() {
        XCTAssertEqual(
            resolveAccess(owned: false, marker: marker, policy: policy, now: at(0)),
            .trial(daysRemaining: 30)
        )
    }

    func testLastSecondOfDayZero() {
        XCTAssertEqual(
            resolveAccess(owned: false, marker: marker, policy: policy, now: at(86399)),
            .trial(daysRemaining: 30)
        )
    }

    func testFirstSecondOfDayOne() {
        XCTAssertEqual(
            resolveAccess(owned: false, marker: marker, policy: policy, now: at(86400)),
            .trial(daysRemaining: 29)
        )
    }

    func testStartOfLastTrialDay() {
        XCTAssertEqual(
            resolveAccess(owned: false, marker: marker, policy: policy, now: at(2_505_600)),
            .trial(daysRemaining: 1)
        )
    }

    func testLastTrialSecond() {
        XCTAssertEqual(
            resolveAccess(owned: false, marker: marker, policy: policy, now: at(2_591_999)),
            .trial(daysRemaining: 1)
        )
    }

    func testExpiryInstant() {
        XCTAssertEqual(resolveAccess(owned: false, marker: marker, policy: policy, now: at(2_592_000)), .expired)
    }

    func testWellPastExpiry() {
        XCTAssertEqual(resolveAccess(owned: false, marker: marker, policy: policy, now: at(31_536_000)), .expired)
    }

    func testClockRollbackClampsToDayZero() {
        XCTAssertEqual(
            resolveAccess(owned: false, marker: marker, policy: policy, now: at(-86400)),
            .trial(daysRemaining: 30)
        )
    }

    func testOneDayPolicyBoundary() {
        let oneDay = TrialPolicy(length: 1)
        XCTAssertEqual(
            resolveAccess(owned: false, marker: marker, policy: oneDay, now: at(86399)),
            .trial(daysRemaining: 1)
        )
        XCTAssertEqual(resolveAccess(owned: false, marker: marker, policy: oneDay, now: at(86400)), .expired)
    }
}
