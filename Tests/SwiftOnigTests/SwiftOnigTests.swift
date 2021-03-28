import XCTest
@testable import SwiftOnig

final class SwiftOnigTests: XCTestCase {
    func testVersion() {
        let ver = SwiftOnig.Version()
        XCTAssertFalse(ver.isEmpty)
        print("Oniguruma version is \(ver)")
    }
    
    func testValidPattern() {
        XCTAssertNotNil(Regex(pattern: ".*", option: .none, syntax: .default))
        XCTAssertNotNil(Regex(pattern: #"a \w+ word"#))
    }
    
    func testInValidPattern() {
        let reg = Regex(pattern: #"\\p{foo}"#)
        XCTAssertNotNil(reg)
    }
    
    func testMatch() {
        if let reg = Regex(pattern: "foo") {
            let res = reg.match(str: "bar", at: 0, options: .none, region: nil)
            XCTAssertEqual(res, 0)
        }
    }

    static var allTests = [
        ("testVersion", testVersion),
        ("testValidPattern", testValidPattern),
        ("testInValidPattern", testInValidPattern),
        ("testMatch", testMatch),
    ]
}
