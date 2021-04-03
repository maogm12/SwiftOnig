//
//  RegexTests.swift
//  
//
//  Created by Gavin Mao on 4/1/21.
//

import XCTest
@testable import SwiftOnig

final class RegexTests: XCTestCase {
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

        XCTAssertEqual(naiveEmailReg.firstIndex(in: target), 13)

        let result = try? naiveEmailReg.search(in: target)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.firstIndex, 13)
        
        let region = result!.region
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(target.subString(utf8BytesRange: region.utf8BytesRange(groupIndex: 0)!),
                       "test@example.com")
    }

    func testName() {
        let reg = try! Regex("(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(reg.nameCount, 3)
        
        reg.forEachName { (name, indice) -> Bool in
            print(name, indice)
            return true
        }
    }
    
    static var allTests = [
        ("testInit", testInit),
        ("testReset", testReset),
        ("testMatch", testMatch),
        ("testSearch", testSearch),
        ("testName", testName),
    ]
}
