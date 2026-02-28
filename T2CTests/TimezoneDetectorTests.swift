//
//  TimezoneDetectorTests.swift
//  T2CTests
//
//  Tests for TimezoneDetector abbreviation matching behavior
//

import XCTest
@testable import T2C

final class TimezoneDetectorTests: XCTestCase {

    func testDetectAbbreviation_requiresUppercaseToken() {
        // Lowercase French "et" should NOT match Eastern Time (ET)
        let french = "Déjeuner avec Marie et Paul demain à 14h"
        XCTAssertNil(TimezoneDetector.detect(in: french), "Lowercase 'et' should not be interpreted as ET")

        // Uppercase ET should match
        let english = "Lunch with Marie ET Paul tomorrow at 2pm"
        let detected = TimezoneDetector.detect(in: english)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.abbreviation, "ET")
        XCTAssertEqual(detected?.timezone.identifier, "America/New_York")
    }

    func testDetectAbbreviation_stillMatchesWithPunctuation() {
        let text = "Call me at 9am ET, please"
        let detected = TimezoneDetector.detect(in: text)
        XCTAssertEqual(detected?.abbreviation, "ET")
        XCTAssertEqual(detected?.timezone.identifier, "America/New_York")
    }

    func testDetect_prefersEarliestTimezoneTokenAcrossTokenTypes() {
        let text = "Meet at 9am ET (UTC-5)"
        let detected = TimezoneDetector.detect(in: text)

        XCTAssertEqual(detected?.abbreviation, "ET")
        XCTAssertEqual(detected?.timezone.identifier, "America/New_York")
    }

    func testDetect_rejectsOffsetsOutsideDocumentedRange() {
        XCTAssertNil(TimezoneDetector.detect(in: "Meet at 9am UTC+14:30"))
        XCTAssertNil(TimezoneDetector.detect(in: "Meet at 9am UTC-12:30"))

        let detected = TimezoneDetector.detect(in: "Meet at 9am UTC+14:00")
        XCTAssertEqual(detected?.abbreviation, "UTC+14:00")
        XCTAssertEqual(detected?.timezone.secondsFromGMT(), 14 * 3600)
    }
}
