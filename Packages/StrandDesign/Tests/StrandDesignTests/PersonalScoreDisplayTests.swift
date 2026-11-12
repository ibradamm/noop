import XCTest
@testable import StrandDesign

final class PersonalScoreDisplayTests: XCTestCase {
    func testStoredWireAxisIsConvertedExactlyOnce() {
        XCTAssertEqual(PersonalScoreDisplay.effortText(stored: 0), "0.0")
        XCTAssertEqual(PersonalScoreDisplay.effortText(stored: 50), "10.5")
        XCTAssertEqual(PersonalScoreDisplay.effortText(stored: 61.3), "12.9")
        XCTAssertEqual(PersonalScoreDisplay.effortText(stored: 100), "21.0")
    }

    func testUnavailableOrCorruptIsNeverAZeroOrClippedScore() {
        for value in [nil, Double.nan, .infinity, -.infinity, -1, 101] as [Double?] {
            XCTAssertNil(PersonalScoreDisplay.effortValue(stored: value))
            XCTAssertNil(PersonalScoreDisplay.effortText(stored: value))
        }
    }
}
