import XCTest
import WhoopProtocol
@testable import StrandAnalytics

final class StrainInputValidityTests: XCTestCase {
    private let hr = (0..<600).map { HRSample(ts: $0, bpm: 160) }

    func testCompiledSyntheticOracle() {
        var lines: [String] = []
        for (name, method) in [("edwards", StrainScorer.Method.edwards), ("banister", .banister)] {
            for sex in ["male", "female"] {
                let score = StrainScorer.strain(hr, maxHR: 190, method: method, sex: sex)
                XCTAssertNotNil(score)
                let line = "[effort-oracle] \(name)|\(sex)|" + score.map { String(format: "%.2f", $0) }!
                lines.append(line)
                print(line)
            }
        }
        // Verbatim compiled Swift stdout: Linux CI job 131540778101, source e6116cf3.
        XCTAssertEqual(lines.joined(separator: "\n"), """
        [effort-oracle] edwards|male|38.66
        [effort-oracle] edwards|female|38.66
        [effort-oracle] banister|male|35.30
        [effort-oracle] banister|female|36.19
        """)
    }

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
        XCTAssertEqual(lines, ["[strain-input] refused=invalid_configuration"])
    }

    func testRefusalReasonsDistinguishSamplesCoverageAndConfiguration() {
        for method in [StrainScorer.Method.edwards, .banister] {
            var rejected = hr
            rejected[60] = HRSample(ts: 60, bpm: 0)
            var lines: [String] = []
            XCTAssertNil(StrainScorer.strain(rejected, maxHR: 190, method: method, diag: { lines.append($0) }))
            XCTAssertEqual(lines.first, "[strain-input] refused=rejected_hr_samples count=1")
            lines = []
            XCTAssertNil(StrainScorer.strain(Array(hr.prefix(19)), maxHR: 190, method: method, diag: { lines.append($0) }))
            XCTAssertEqual(lines.first, "[strain-input] refused=insufficient_coverage")
            lines = []
            XCTAssertNil(StrainScorer.strain(hr, maxHR: 60, restingHR: 60, method: method, diag: { lines.append($0) }))
            XCTAssertEqual(lines.first, "[strain-input] refused=invalid_configuration")
        }
    }
}
