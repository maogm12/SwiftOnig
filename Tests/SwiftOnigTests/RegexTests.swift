//
//  RegexTests.swift
//  
//
//  Created by Gavin Mao on 4/1/21.
//

import XCTest
@testable import SwiftOnig

final class RegexTests: SwiftOnigTestsBase {
    func testInit() async {
        let r1 = try? await Regex(pattern: "(a+)(b+)(c+)")
        XCTAssertNotNil(r1)
        let r2 = try? await Regex(pattern: "+++++")
        XCTAssertNil(r2)
        await XCTAssertThrowsSpecific(try await Regex(pattern: "???"), OnigError.targetOfRepeatOperatorNotSpecified)
    }

    func testMatch() async {
        let reg = try! await Regex(pattern: "foo")

        XCTAssertTrue(try! reg.isMatch(in: "foo"))
        XCTAssertFalse(try! reg.isMatch(in: "bar"))

        XCTAssertEqual(try! reg.matchCount(in: "foo"), 3)
        XCTAssertEqual(try! reg.matchCount(in: "foo bar"), 3)
        XCTAssertEqual(try! reg.matchCount(in: "afoo bar", of: 1...), 3)
        XCTAssertNil(try! reg.matchCount(in: "bar"))
    }
    
    func testSearch() async {
        let naiveEmailReg = try! await Regex(pattern: #"\w+@\w+\.com"#)
        let target = "Naive email: test@example.com. :)"

        var region = try! naiveEmailReg.firstMatch(in: target)!
        XCTAssertNotNil(region)
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region[0]?.range, 13..<29)
        XCTAssertEqual(region[0]?.string, "test@example.com")
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        let regGb18030 = try! await Regex(patternBytes: gb18030Bytes, encoding: .gb18030)
        let gb18030String: [UInt8] = [196, 227, 186, 195, 163, 172, 202, 192, 189, 231] // 你好，世界
        region = try! regGb18030.firstMatch(in: gb18030String)!
        XCTAssertNotNil(region)
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region[0]?.range, 0..<4)
        XCTAssertEqual(region[0]?.string, "你好")
    }
    
    func testEnumerateMatches() async {
        let reg = try! await Regex(pattern: #"\d+"#)
        var result = [(Int, Region)]()
        try! reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            result.append(($1, $2))
            return true
        }

        XCTAssertEqual(result.map { $0.0 }, [2, 6, 10, 14])
        XCTAssertEqual(result.map { $0.1[0]!.range }, [2..<4, 6..<8, 10..<12, 14..<16])
        XCTAssertEqual(result.map { $0.1[0]!.string }, ["11", "22", "33", "44"])

        // Abort enumeration
        var resultFirst2 = [(Int, Region)]()
        try! reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            resultFirst2.append(($1, $2))
            return resultFirst2.count < 2
        }

        XCTAssertEqual(resultFirst2.map { $0.0 }, [2, 6])
        XCTAssertEqual(resultFirst2.map { $0.1[0]!.range }, [2..<4, 6..<8])
        XCTAssertEqual(resultFirst2.map { $0.1[0]!.string }, ["11", "22"])
    }

    func testNamedCaptureGroups() async {
        /*
        let reg = try! await Regex(pattern: "(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(reg.namedCaptureGroupsCount, 3)
        
        final class Results: @unchecked Sendable {
            var items = [(name: String, numbers: [Int])]()
        }
        let results = Results()
        
        reg.enumerateCaptureGroupNames { (name, numbers) -> Bool in
            results.items.append((name: name, numbers: numbers))
            return true
        }

        // Names are sorted alphabetically in Oniguruma's foreach
        let names = results.items.map { $0.name }.sorted()
        XCTAssertTrue(names.contains("a"))
        XCTAssertTrue(names.contains("b"))
        XCTAssertTrue(names.contains("bc"))
        
        XCTAssertEqual(reg.captureGroupNumbers(for: "a"), [1, 4])
        XCTAssertEqual(reg.captureGroupNumbers(for: "b"), [2])
        XCTAssertEqual(reg.captureGroupNumbers(for: "c"), [])
        */
    }
    
    func testCaptureGroups() async {
        let reg = try! await Regex(pattern: #"(?<name>\w+):\s+(?<id>\d+)(\s+)(//.*)"#)
        XCTAssertEqual(reg.captureGroupsCount, 2) // ONLY NON-NAMED GROUPS are counted by onig_number_of_captures in some versions
    }

    static let allTests = [
        ("testInit", testInit),
        ("testMatch", testMatch),
        ("testSearch", testSearch),
        ("testEnumerateMatches", testEnumerateMatches),
        // ("testNamedCaptureGroups", testNamedCaptureGroups),
        ("testCaptureGroups", testCaptureGroups),
    ]
}
