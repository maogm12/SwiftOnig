import XCTest
@testable import SwiftOnig

final class SwiftOnigTests: SwiftOnigTestsBase {
    func testVersion() {
        let ver = SwiftOnig.version()
        XCTAssertFalse(ver.isEmpty)
        print("Oniguruma version is \(ver)")
    }

    static var allTests = [
        ("testVersion", testVersion),
    ]
}
