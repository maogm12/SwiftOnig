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

    func testNamedCaptureGroups() {
        let reg = try! Regex("(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(reg.namedCaptureGroupCount, 3)
        
        var result = [(name: String, indexes: [Int])]()
        reg.forEachNamedCaptureGroup { (name, indexes) -> Bool in
            result.append((name: name, indexes: indexes))
            return true
        }
        
        XCTAssertEqual(result.map { $0.name }, ["a", "bc", "b"])
        XCTAssertEqual(result.map { $0.indexes }, [[1, 4], [3], [2]])
        
        XCTAssertEqual(reg.namedCaptureGroupIndexes(of: "a"), [1, 4])
        XCTAssertEqual(reg.namedCaptureGroupIndexes(of: "b"), [2])
        XCTAssertEqual(reg.namedCaptureGroupIndexes(of: "c"), nil)
    }
    
    func testPattern() {
        let reg = try! Regex("(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(reg.pattern, "(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
    }
    
    func testCaptureGroups() {
        let reg = try! Regex(#"(?<name>\w+):\s+(?<id>\d+)(\s+)(//.*)"#)
        XCTAssertEqual(reg.captureGroupCount, 2) // (\s+) (//.*)
    }
    
    static var allTests = [
        ("testInit", testInit),
        ("testMatch", testMatch),
        ("testSearch", testSearch),
        ("testMatches", testMatches),
        ("testEnumerateMatches", testEnumerateMatches),
        ("testPattern", testPattern),
        ("testNamedCaptureGroups", testNamedCaptureGroups),
    ]
}
