import XCTest

@testable import ASCMetadataCore

final class KeywordValidatorTests: XCTestCase {
    func testValidKeywordsPassCleanly() {
        let result = KeywordValidator.validate("run,walk,jog")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.charCount, 12)
        XCTAssertEqual(result.maxChars, 100)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testExceedingCharLimitFails() {
        let long = String(repeating: "a", count: 101)
        let result = KeywordValidator.validate(long)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.charCount, 101)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("100") ?? false)
    }

    func testCustomMaxCharsRespected() {
        let result = KeywordValidator.validate("abcdef", maxChars: 5)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.maxChars, 5)
    }

    func testSpacesAfterCommasWarn() {
        let result = KeywordValidator.validate("run, walk")
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.warnings.contains { $0.localizedCaseInsensitiveContains("space") })
    }

    func testDuplicatesWarn() {
        let result = KeywordValidator.validate("run,run")
        XCTAssertTrue(result.warnings.contains { $0.localizedCaseInsensitiveContains("duplicate") })
    }

    func testPluralSingularWarns() {
        let result = KeywordValidator.validate("cat,cats")
        XCTAssertTrue(result.warnings.contains { $0.localizedCaseInsensitiveContains("plural") })
    }
}
