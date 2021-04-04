import XCTest
@testable import SwiftOnig

internal class SwiftOnigTestsBase: XCTestCase {
    override class func setUp() {
        try! SwiftOnig.initialize(encodings: [.utf8])
    }
    
    override class func tearDown() {
        SwiftOnig.uninitialize()
    }
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

