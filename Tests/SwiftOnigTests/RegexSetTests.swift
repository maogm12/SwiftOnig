//
//  RegexSet.swift
//  
//
//  Created by Gavin Mao on 4/2/21.
//


import XCTest
@testable import SwiftOnig

final class RegexSetTests: SwiftOnigTestsBase {
    func testInit() {
        let regSet = try! RegexSet(regexes: [Regex(pattern: "a+"), Regex(pattern: "b+")])
        XCTAssertEqual(regSet.count, 2)
    }
    
    func testGetter() {
        let regSet = try! RegexSet(regexes: [Regex(pattern: "a+"), Regex(pattern: "b+")])
        let regex1 = regSet[0]
        XCTAssertTrue(regex1.isMatch("aaaa"))
        XCTAssertFalse(regex1.isMatch("bbbb"))
    }

    func testSearch() {
        let regSet = try! RegexSet(regexes: [Regex(pattern: "a+"), Regex(pattern: "b+"), Regex(pattern: "c+")])

        var result = try! regSet.firstMatch(in: "cccaaabbb", lead: .positionLead)!
        XCTAssertEqual(result.regexIndex, 2)
        XCTAssertEqual(result.region.range, 0..<3)
        XCTAssertEqual(result.region.string, "ccc")

        result = try! regSet.firstMatch(in: "cccaaabbb", lead: .regexLead)!
        XCTAssertEqual(result.regexIndex, 2)
        XCTAssertEqual(result.region.range, 0..<3)
        XCTAssertEqual(result.region.string, "ccc")

        result = try! regSet.firstMatch(in: "cccaaabbb", lead: .priorityToRegexOrder)!
        XCTAssertEqual(result.regexIndex, 0)
        XCTAssertEqual(result.region.range, 3..<6)
        XCTAssertEqual(result.region.string, "aaa")
    }

    static var allTests = [
        ("testInit", testInit),
        ("testGetter", testGetter),
        ("testSearch", testSearch),
    ]
}
