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
        XCTAssertEqual(try! reg.match("foo"), 3)

        XCTAssertFalse(try! reg.isMatch("bar"))
        XCTAssertNil(try! reg.match("bar"))

        try! reg.reset(#"a(.*)b|[e-f]+"#)
        XCTAssertTrue(try! reg.isMatch("affffffffb"))
        XCTAssertEqual(try! reg.match("affffffffb"), 10)

        XCTAssertTrue(try! reg.isMatch("efefefefef"))
        XCTAssertEqual(try! reg.match("efefefefef"), 10)

        XCTAssertFalse(try! reg.isMatch("zzzzaffffffffb"))
        XCTAssertNil(try! reg.match("zzzzaffffffffb"))
        
        try! reg.reset(#"\w"#)
        XCTAssertEqual(try! reg.match("a"), 1)
    }
    
    func testSearch() {
        let emailReg = try! Regex(#"\w+@\w+\.com"#)
        let result = try! emailReg.search("Naive email: test@example.com. :)")
        XCTAssertEqual(result, 13)
    }
    
    func testRegionTree() {
        var syntax = Syntax.ruby
        syntax.enableOperators(operators: .atmarkCaptureHistory)
        let reg = try! Regex(#"(?@a+(?@b+))|(?@c+(?@d+))"#, option: .none, syntax: syntax)
        let region = Region()
        let str = "- cd aaabbb -"
        let result = try! reg.search(str, options: .none, region: region, matchParam: MatchParam())
        
        XCTAssertEqual(result, 2)
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
