//
//  RegexSetTests.swift
//  
//
//  Created by Gavin Mao on 4/2/21.
//


import XCTest
@testable import SwiftOnig

final class RegexSetTests: SwiftOnigTestsBase {
    func testInit() async {
        var regSet = try! await RegexSet(regexes: [try await Regex(pattern: "a+"), try await Regex(pattern: "b+")])
        XCTAssertEqual(regSet.count, 2)
        
        regSet = try! await RegexSet(patterns: ["a+", "b+", "c+"])
        XCTAssertEqual(regSet.count, 3)
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        regSet = try! await RegexSet(patternsBytes: [gb18030Bytes], encoding: .gb18030)
        XCTAssertEqual(regSet.count, 1)
    }
    
    func testGetter() async {
        let regSet = try! await RegexSet(regexes: [try await Regex(pattern: "a+"), try await Regex(pattern: "b+")])
        let regex1 = regSet[0]
        let m1 = try! await regex1.matches("aaaa")
        XCTAssertTrue(m1)
        let m2 = try! await regex1.matches("bbbb")
        XCTAssertFalse(m2)
    }

    func testSearch() async {
        let regSet = try! await RegexSet(regexes: [try await Regex(pattern: "a+"), try await Regex(pattern: "b+"), try await Regex(pattern: "c+")])

        var result = try! await regSet.firstMatch(in: "cccaaabbb", lead: .positionLead)!
        XCTAssertEqual(result.regexIndex, 2)
        XCTAssertEqual(result.region.range, 0..<3)
        XCTAssertEqual(result.region.string, "ccc")

        result = try! await regSet.firstMatch(in: "cccaaabbb", lead: .regexLead)!
        XCTAssertEqual(result.regexIndex, 2)
        XCTAssertEqual(result.region.range, 0..<3)
        XCTAssertEqual(result.region.string, "ccc")

        result = try! await regSet.firstMatch(in: "cccaaabbb", lead: .priorityToRegexOrder)!
        XCTAssertEqual(result.regexIndex, 0)
        XCTAssertEqual(result.region.range, 3..<6)
        XCTAssertEqual(result.region.string, "aaa")

        let gb18030Bytes1: [UInt8] = [202, 192, 189, 231] // 世界
        let gb18030Bytes2: [UInt8] = [196, 227, 186, 195] // 你好
        let regSetGb18030 = try! await RegexSet(patternsBytes: [gb18030Bytes1, gb18030Bytes2],
                                          encoding: .gb18030)
        let target: [UInt8] = [196, 227, 186, 195, 163, 172, 208, 194, 202, 192, 189, 231, 163, 161] // 你好，新世界！
        result = try! await regSetGb18030.firstMatch(in: target)!
        XCTAssertEqual(result.regexIndex, 1)
        XCTAssertEqual(result.region.range, 0..<4)
        XCTAssertEqual(result.region.string, "你好")
    }

    static let allTests = [
        ("testInit", testInit),
        ("testGetter", testGetter),
        ("testSearch", testSearch),
    ]
}
