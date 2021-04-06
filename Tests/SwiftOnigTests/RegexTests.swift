//
//  RegexTests.swift
//  
//
//  Created by Gavin Mao on 4/1/21.
//

import XCTest
@testable import SwiftOnig

final class RegexTests: SwiftOnigTestsBase {
    func testInit() {
        XCTAssertNotNil(try? Regex("(a+)(b+)(c+)"))
        XCTAssertNil(try? Regex("+++++"))
        XCTAssertThrowsSpecific(try Regex("???"), OnigError.targetOfRepeatOperatorNotSpecified)
    }
    
    func testReset() {
        let reg = try! Regex("a+")
        XCTAssertTrue(reg.isMatch("aaaaa"))
        XCTAssertFalse(reg.isMatch("bbbbb"))

        try! reg.reset("b+")
        XCTAssertFalse(reg.isMatch("aaaaa"))
        XCTAssertTrue(reg.isMatch("bbbbb"))
        
        try? reg.reset("+++")
        XCTAssertFalse(reg.isMatch("aaaaa"))
        XCTAssertFalse(reg.isMatch("bbbbb"))
    }

    func testMatch() {
        let reg = try! Regex("foo")

        XCTAssertTrue(reg.isMatch("foo"))
        XCTAssertFalse(reg.isMatch("bar"))

        XCTAssertEqual(reg.matchedByteCount(in: "foo"), 3)
        XCTAssertEqual(reg.matchedByteCount(in: "foo bar"), 3)
        XCTAssertNil(reg.matchedByteCount(in: "bar"))

        XCTAssertNil(try! reg.match(in: "bar foo"))
        XCTAssertNil(try! reg.match(in: "bar"))
    }
    
    func testSearch() {
        let naiveEmailReg = try! Regex(#"\w+@\w+\.com"#)
        let target = "Naive email: test@example.com. :)"

        XCTAssertEqual(try? naiveEmailReg.firstIndex(in: target), 13)

        let region = try! naiveEmailReg.firstMatch(in: target)!
        XCTAssertNotNil(region)
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region.utf8BytesRange(groupIndex: 0), 13..<29)
        XCTAssertEqual(target.subString(utf8BytesRange: region.utf8BytesRange(groupIndex: 0)!),
                       "test@example.com")
    }
    
    func testMatches() {
        let reg = try! Regex(#"\d+"#)
        let regions = try! reg.matches(in: "aa11bb22cc33dd44")
        XCTAssertEqual(regions.count, 4)
        XCTAssertEqual(regions.map { $0.utf8BytesRange(groupIndex: 0)! }, [2..<4, 6..<8, 10..<12, 14..<16])
    }
    
    func testEnumerateMatches() {
        let reg = try! Regex(#"\d+"#)
        var result = [(Int, Region)]()
        try! reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            result.append(($0, $1))
            return true
        }

        XCTAssertEqual(result.map { $0.0 }, [2, 6, 10, 14])
        XCTAssertEqual(result.map { $0.1.utf8BytesRange(groupIndex: 0)! }, [2..<4, 6..<8, 10..<12, 14..<16])
    }

    func testName() {
        let reg = try! Regex("(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(reg.nameCount, 3)
        
        reg.forEachName { (name, indice) -> Bool in
            print(name, indice)
            return true
        }
    }
    
    func testPattern() {
        let reg = try! Regex("(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(reg.pattern, "(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
    }
    
    static var allTests = [
        ("testInit", testInit),
        ("testReset", testReset),
        ("testMatch", testMatch),
        ("testSearch", testSearch),
        ("testMatches", testMatches),
        ("testEnumerateMatches", testEnumerateMatches),
        ("testName", testName),
        ("testPattern", testPattern),
    ]
}
