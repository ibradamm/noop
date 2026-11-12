import XCTest
import StrandDesign
@testable import Strand

final class PersonalSnapshotCompatibilityTests: XCTestCase {
    func testOldWatchPayloadStillDecodesWithoutChangingStoredAxisOrHistory() throws {
        let old = WatchScoreSnapshot(charge: 72, chargeCalibrating: false,
                                     effort: 61.3, effortCalibrating: false,
                                     rest: 81, restCalibrating: false, hr: nil,
                                     sleepSummary: "", asOf: .distantPast)
        let data = try JSONEncoder().encode(old)
        let decoded = try JSONDecoder().decode(WatchScoreSnapshot.self, from: data)
        XCTAssertNil(decoded.personalPolicyVersion)
        XCTAssertEqual(decoded.charge, 72) // Retained for compatibility, never a personal UI readout.
        XCTAssertEqual(decoded.effort, 61.3)
        XCTAssertEqual(PersonalScoreDisplay.effortText(stored: decoded.effort), "12.9")
    }

    func testPreciseWidgetFieldIsAdditiveAndTriggersAnUpdate() throws {
        let old = WidgetSnapshot(recovery: 72, bpm: nil, batteryPct: nil, bonded: false,
                                 updated: .distantPast, effort: 61)
        let oldDecoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(old))
        XCTAssertNil(oldDecoded.effortStored)
        XCTAssertNil(oldDecoded.personalPolicyVersion)
        XCTAssertEqual(oldDecoded.recovery, 72)
        var current = old
        current.recovery = nil
        current.effortStored = 61.3
        current.personalPolicyVersion = PersonalScoreDisplay.policyVersion
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(current))
        XCTAssertEqual(decoded.effort, 61) // Legacy integer contract has not changed to 0–21.
        XCTAssertEqual(decoded.effortStored, 61.3)
        XCTAssertEqual(PersonalScoreDisplay.effortText(stored: decoded.effortStored), "12.9")
        XCTAssertTrue(WidgetSnapshot.renderedContentChanged(from: old, to: decoded))
        var corrected = decoded
        corrected.effortStored = 61.4
        XCTAssertTrue(WidgetSnapshot.renderedContentChanged(from: decoded, to: corrected))
    }
}
