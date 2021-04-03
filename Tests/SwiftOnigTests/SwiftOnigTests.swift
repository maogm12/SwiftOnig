import XCTest
@testable import SwiftOnig

final class SwiftOnigTests: XCTestCase {
    func testVersion() {
        let ver = SwiftOnig.version()
        XCTAssertFalse(ver.isEmpty)
        print("Oniguruma version is \(ver)")
    }

    func testRegionTree() {
        let syntax = Syntax.ruby
        syntax.operators.insert(.atmarkCaptureHistory)
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
