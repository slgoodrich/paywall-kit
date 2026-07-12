import Foundation
import PurchaseKit
import XCTest

final class KeychainTrialMarkerStoreTests: XCTestCase {
    private var store: KeychainTrialMarkerStore!

    override func setUp() {
        super.setUp()
        store = KeychainTrialMarkerStore(service: "paywall-kit-tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? store.clear()
        store = nil
        super.tearDown()
    }

    func testReadWithoutMarkerReturnsNil() throws {
        XCTAssertNil(try store.read())
    }

    func testStartIfAbsentPersistsAndRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_783_468_800.5)
        try store.startIfAbsent(now: now)
        let read = try XCTUnwrap(store.read())
        XCTAssertEqual(read.startedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    func testStartIfAbsentIsIdempotent() throws {
        let now = Date(timeIntervalSince1970: 1_783_468_800)
        let first = try store.startIfAbsent(now: now)
        let second = try store.startIfAbsent(now: now.addingTimeInterval(10 * 86400))
        XCTAssertEqual(
            first.startedAt.timeIntervalSince1970,
            second.startedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testClearRemovesMarker() throws {
        try store.startIfAbsent(now: Date(timeIntervalSince1970: 1_783_468_800))
        try store.clear()
        XCTAssertNil(try store.read())
    }

    func testClearWithoutMarkerSucceeds() throws {
        XCTAssertNoThrow(try store.clear())
    }
}
