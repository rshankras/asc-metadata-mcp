import XCTest

@testable import ASCMetadataCore

final class CSVParserTests: XCTestCase {
    func testParsesTabSeparated() {
        let parsed = CSVParser.parse("a\tb\tc\n1\t2\t3")
        XCTAssertEqual(parsed.headers, ["a", "b", "c"])
        XCTAssertEqual(parsed.rows, [["1", "2", "3"]])
    }

    func testStripsQuotes() {
        let parsed = CSVParser.parse("\"a\"\t\"b\"\n\"x\"\t\"y\"")
        XCTAssertEqual(parsed.headers, ["a", "b"])
        XCTAssertEqual(parsed.rows, [["x", "y"]])
    }

    func testCustomDelimiter() {
        let parsed = CSVParser.parse("a,b\n1,2", delimiter: ",")
        XCTAssertEqual(parsed.headers, ["a", "b"])
        XCTAssertEqual(parsed.rows, [["1", "2"]])
    }

    func testEmptyInputYieldsNoHeadersOrRows() {
        let parsed = CSVParser.parse("")
        XCTAssertTrue(parsed.headers.isEmpty)
        XCTAssertTrue(parsed.rows.isEmpty)
    }

    func testHeaderOnlyHasNoRows() {
        let parsed = CSVParser.parse("a\tb")
        XCTAssertEqual(parsed.headers, ["a", "b"])
        XCTAssertTrue(parsed.rows.isEmpty)
    }
}
