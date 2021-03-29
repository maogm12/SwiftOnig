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
        XCTAssertTrue(try! reg.match("foo"))
        XCTAssertFalse(try! reg.match("bar"))

        try! reg.reset(#"a(.*)b|[e-f]+"#)
        XCTAssertTrue(try! reg.match("affffffffb"))
        XCTAssertTrue(try! reg.match("efefefefef"))
        XCTAssertFalse(try! reg.match("zzzzaffffffffb"))
    }

    static var allTests = [
        ("testVersion", testVersion),
        ("testValidPattern", testValidPattern),
        ("testInValidPattern", testInValidPattern),
        ("testMatch", testMatch),
    ]
}
