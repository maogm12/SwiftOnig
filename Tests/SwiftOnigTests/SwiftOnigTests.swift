import XCTest
@testable import SwiftOnig

final class SwiftOnigTests: XCTestCase {
    func testVersion() {
        let ver = SwiftOnig.Version()
        XCTAssertFalse(ver.isEmpty)
        print("Oniguruma version is \(ver)")
    }
    
    func testValidPattern() {
        var reg = try? Regex(".*")
        XCTAssertNotNil(reg)
        reg = try? Regex(#"a \w+ word"#)
        XCTAssertNotNil(reg)
    }
    
    func testInValidPattern() {
        let reg = try? Regex(#"\\p{foo}"#)
        XCTAssertNotNil(reg)
    }
    
    func testMatch() {
        let reg = try! Regex("foo")
        XCTAssertTrue(try! reg.isMatch("foo"))
        XCTAssertEqual(try! reg.matchedByteCount(in: "foo"), 3)
        XCTAssertNil(try! reg.match(in: "bar foo"))
        XCTAssertEqual(try! reg.matchedByteCount(in: "foo bar"), 3)

        XCTAssertFalse(try! reg.isMatch("bar"))
        XCTAssertNil(try! reg.match(in: "bar"))

        try! reg.reset(#"a(.*)b|[e-f]+"#)
        XCTAssertTrue(try! reg.isMatch("affffffffb"))
        XCTAssertEqual(try! reg.matchedByteCount(in: "affffffffb"), 10)

        XCTAssertTrue(try! reg.isMatch("efefefefef"))
        XCTAssertEqual(try! reg.matchedByteCount(in: "efefefefef"), 10)

        XCTAssertFalse(try! reg.isMatch("zzzzaffffffffb"))
        XCTAssertNil(try! reg.match(in: "zzzzaffffffffb"))
        
        try! reg.reset(#"\w"#)
        XCTAssertEqual(try! reg.matchedByteCount(in: "a"), 1)
    }
    
    func testSearch() {
        let emailReg = try! Regex(#"\w+@\w+\.com"#)
        XCTAssertEqual(try! emailReg.firstIndex(in: "Naive email: test@example.com. :)"), 13)
    }

    func testRegionTree() {
        let syntax = Syntax.ruby
        syntax.enableOperators(operators: .atmarkCaptureHistory)
        let reg = try! Regex(#"(?@a+(?@b+))|(?@c+(?@d+))"#, option: .none, syntax: syntax)
        guard let (firstIndex, region) = try! reg.search(in: "- cd aaabbb -") else {
            XCTFail("Should match")
            return
        }

        XCTAssertEqual(firstIndex, 2)
        XCTAssertEqual(region.count, 5)

        let tree = region.tree!
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree.group, 0)
        XCTAssertEqual(tree.utf8BytesRange, 2..<4)

        XCTAssertEqual(tree[0].count, 1)
        XCTAssertEqual(tree[0].group, 3)
        XCTAssertEqual(tree[0].utf8BytesRange, 2..<4)
        
        XCTAssertEqual(tree[0][0].count, 0)
        XCTAssertEqual(tree[0][0].group, 4)
        XCTAssertEqual(tree[0][0].utf8BytesRange, 3..<4)
    }

    static var allTests = [
        ("testVersion", testVersion),
        ("testValidPattern", testValidPattern),
        ("testInValidPattern", testInValidPattern),
        ("testMatch", testMatch),
        ("testSearch", testSearch),
        ("testRegionTree", testRegionTree),
    ]
}

extension XCTestCase {
    internal func XCTAssertThrowsSpecific<T, E: Error & Equatable>(
        _ expression: @autoclosure () throws -> T,
        _ error: E,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var thrownError: Error?

        XCTAssertThrowsError(try expression(),
                             file: file, line: line) {
            thrownError = $0
        }

        XCTAssertTrue(
            thrownError is E,
            "Unexpected error type: \(type(of: thrownError))",
            file: file, line: line
        )

        XCTAssertEqual(
            thrownError as? E, error,
            file: file, line: line
        )
    }
}
