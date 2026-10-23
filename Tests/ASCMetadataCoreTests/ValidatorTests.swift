import XCTest

@testable import ASCMetadataCore

final class CharLimitValidatorTests: XCTestCase {
    func testWithinLimitPasses() {
        let result = CharLimitValidator.validate("Hello", field: "Name", maxChars: 30)
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
    }

    func testExceedingLimitFailsWithField() {
        let result = CharLimitValidator.validate(String(repeating: "x", count: 31), field: "Name", maxChars: 30)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.error?.contains("Name") ?? false)
        XCTAssertTrue(result.error?.contains("30") ?? false)
    }

    func testBoundaryIsInclusive() {
        let result = CharLimitValidator.validate(String(repeating: "x", count: 30), field: "Name", maxChars: 30)
        XCTAssertTrue(result.isValid)
    }
}

final class LocaleHelperTests: XCTestCase {
    func testKnownLocalesAreValid() {
        XCTAssertTrue(LocaleHelper.validate("en-US"))
        XCTAssertTrue(LocaleHelper.validate("de-DE"))
        XCTAssertTrue(LocaleHelper.validate("zh-Hans"))
    }

    func testUnknownLocalesAreInvalid() {
        XCTAssertFalse(LocaleHelper.validate("xx-YY"))
        XCTAssertFalse(LocaleHelper.validate(""))
        XCTAssertFalse(LocaleHelper.validate("en_US"))  // underscore, not hyphen
    }
}
