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

        let m1 = try! await reg.matches("foo")
        XCTAssertTrue(m1)
        let m2 = try! await reg.matches("bar")
        XCTAssertFalse(m2)

        let c1 = try! await reg.matchCount(in: "foo")
        XCTAssertEqual(c1, 3)
        let c2 = try! await reg.matchCount(in: "foo bar")
        XCTAssertEqual(c2, 3)
        let c3 = try! await reg.matchCount(in: "afoo bar", of: 1...)
        XCTAssertEqual(c3, 3)
        let c4 = try! await reg.matchCount(in: "bar")
        XCTAssertNil(c4)
    }
    
    func testSearch() async {
        let naiveEmailReg = try! await Regex(pattern: #"\w+@\w+\.com"#)
        let target = "Naive email: test@example.com. :)"

        var region = try! await naiveEmailReg.firstMatch(in: target)!
        XCTAssertNotNil(region)
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region[0]?.range, 13..<29)
        XCTAssertEqual(region[0]?.string, "test@example.com")
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        let regGb18030 = try! await Regex(patternBytes: gb18030Bytes, encoding: .gb18030)
        let gb18030String: [UInt8] = [196, 227, 186, 195, 163, 172, 202, 192, 189, 231] // 你好，世界
        region = try! await regGb18030.firstMatch(in: gb18030String)!
        XCTAssertNotNil(region)
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region[0]?.range, 0..<4)
        XCTAssertEqual(region[0]?.string, "你好")
    }
    
    func testEnumerateMatches() async {
        let reg = try! await Regex(pattern: #"\d+"#)
        
        final class Results: @unchecked Sendable {
            var items = [(Int, Region)]()
        }
        let results = Results()
        
        try! await reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            results.items.append(($1, $2))
            return true
        }

        XCTAssertEqual(results.items.map { $0.0 }, [2, 6, 10, 14])
        XCTAssertEqual(results.items.map { $0.1[0]!.range }, [2..<4, 6..<8, 10..<12, 14..<16])
        XCTAssertEqual(results.items.map { $0.1[0]!.string }, ["11", "22", "33", "44"])

        // Abort enumeration
        let resultsFirst2 = Results()
        try! await reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            resultsFirst2.items.append(($1, $2))
            return resultsFirst2.items.count < 2
        }

        XCTAssertEqual(resultsFirst2.items.map { $0.0 }, [2, 6])
        XCTAssertEqual(resultsFirst2.items.map { $0.1[0]!.range }, [2..<4, 6..<8])
        XCTAssertEqual(resultsFirst2.items.map { $0.1[0]!.string }, ["11", "22"])
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
        ("testNamedCaptureGroups", testNamedCaptureGroups),
        ("testCaptureGroups", testCaptureGroups),
    ]
}
