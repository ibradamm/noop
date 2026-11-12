import XCTest
import WhoopProtocol
@testable import StrandAnalytics

final class StrainInputValidityTests: XCTestCase {
    private let hr = (0..<600).map { HRSample(ts: $0, bpm: 160) }

    func testInvalidConfigurationIsUnavailableForBothRecipes() {
        for method in [StrainScorer.Method.edwards, .banister] {
            for invalid in [Double.nan, .infinity, -.infinity] {
                XCTAssertNil(StrainScorer.strain(hr, maxHR: invalid, method: method))
                XCTAssertNil(StrainScorer.strain(hr, restingHR: invalid, method: method))
                XCTAssertNil(StrainScorer.strain(hr, method: method, denominator: invalid))
            }
            for invalid in [1.0, 0.0, -1.0] {
                XCTAssertNil(StrainScorer.strain(hr, method: method, denominator: invalid))
            }
            XCTAssertNil(StrainScorer.strain(hr, restingHR: 0, method: method))
            XCTAssertNil(StrainScorer.strain(hr, restingHR: -1, method: method))
        }
    }

    func testOneCorruptReadingRefusesTheWindowRatherThanSilentlyDroppingIt() {
        for bpm in [0, -1] {
            var corrupt = hr
            corrupt[60] = HRSample(ts: 60, bpm: bpm)
            for method in [StrainScorer.Method.edwards, .banister] {
                XCTAssertNil(StrainScorer.strain(corrupt, maxHR: 190, method: method))
            }
        }
    }

    func testValidZeroAndMissingDataStayDifferentAndDiagnosticIsAvailable() {
        let calm = (0..<600).map { HRSample(ts: $0, bpm: 60) }
        XCTAssertEqual(StrainScorer.strain(calm, maxHR: 190), 0)
        XCTAssertNil(StrainScorer.strain([], maxHR: 190))
        XCTAssertGreaterThan(StrainScorer.strain(hr, maxHR: 190) ?? 0, 0)
        var lines: [String] = []
        XCTAssertNil(StrainScorer.strain(hr, maxHR: .nan, diag: { lines.append($0) }))
        XCTAssertEqual(lines, ["[strain-input] refused=invalid_numeric_input"])
    }
}
