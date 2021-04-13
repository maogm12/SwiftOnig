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
        XCTAssertNotNil(try? Regex(pattern: "(a+)(b+)(c+)"))
        XCTAssertNil(try? Regex(pattern: "+++++"))
        XCTAssertThrowsSpecific(try Regex(pattern: "???"), OnigError.targetOfRepeatOperatorNotSpecified)
    }

    func testMatch() {
        let reg = try! Regex(pattern: "foo")

        XCTAssertTrue(reg.isMatch("foo"))
        XCTAssertFalse(reg.isMatch("bar"))

        XCTAssertEqual(try! reg.matchedByteCount(in: "foo"), 3)
        XCTAssertEqual(try! reg.matchedByteCount(in: "foo bar"), 3)
        XCTAssertNil(try! reg.matchedByteCount(in: "bar"))

        XCTAssertNil(try! reg.match(in: "bar foo"))
        XCTAssertNil(try! reg.match(in: "bar"))
    }
    
    func testSearch() {
        let naiveEmailReg = try! Regex(pattern: #"\w+@\w+\.com"#)
        let target = "Naive email: test@example.com. :)"

        XCTAssertEqual(try? naiveEmailReg.firstIndex(in: target), 13)

        var region = try! naiveEmailReg.firstMatch(in: target)!
        XCTAssertNotNil(region)
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region[0]?.range, 13..<29)
        XCTAssertEqual(region[0]?.string, "test@example.com")
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        let regGb18030 = try! Regex(patternBytes: gb18030Bytes, encoding: .gb18030)
        let gb18030String: [UInt8] = [196, 227, 186, 195, 163, 172, 202, 192, 189, 231] // 你好，世界
        region = try! regGb18030.firstMatch(in: gb18030String)!
        XCTAssertNotNil(region)
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region[0]?.range, 0..<4)
        XCTAssertEqual(region[0]?.string, "你好")
    }
    
    func testMatches() {
        let reg = try! Regex(pattern: #"\d+"#)
        let regions = try! reg.matches(in: "aa11bb22cc33dd44")
        XCTAssertEqual(regions.count, 4)
        XCTAssertEqual(regions.map { $0[0]!.range }, [2..<4, 6..<8, 10..<12, 14..<16])
    }
    
    func testEnumerateMatches() {
        let reg = try! Regex(pattern: #"\d+"#)
        var result = [(Int, Region)]()
        try! reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            result.append(($0, $1))
            return true
        }

        XCTAssertEqual(result.map { $0.0 }, [2, 6, 10, 14])
        XCTAssertEqual(result.map { $0.1[0]!.range }, [2..<4, 6..<8, 10..<12, 14..<16])
        XCTAssertEqual(result.map { $0.1[0]!.string }, ["11", "22", "33", "44"])

        // Abort enumeration
        var resultFirst2 = [(Int, Region)]()
        try! reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            resultFirst2.append(($0, $1))
            return resultFirst2.count < 2
        }

        XCTAssertEqual(resultFirst2.map { $0.0 }, [2, 6])
        XCTAssertEqual(resultFirst2.map { $0.1[0]!.range }, [2..<4, 6..<8])
        XCTAssertEqual(resultFirst2.map { $0.1[0]!.string }, ["11", "22"])
    }

    func testNamedCaptureGroups() {
        let reg = try! Regex(pattern: "(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(reg.captureGroupNameCount, 3)
        
        var result = [(name: String, numbers: [Int])]()
        reg.enumerateCaptureGroupNames { (name, numbers) -> Bool in
            result.append((name: name, numbers: numbers))
            return true
        }

        XCTAssertEqual(result.map { $0.name }, ["a", "bc", "b"])
        XCTAssertEqual(result.map { $0.numbers }, [[1, 4], [3], [2]])
        
        XCTAssertEqual(reg.captureGroupNumbers(of: "a"), [1, 4])
        XCTAssertEqual(reg.captureGroupNumbers(of: "b"), [2])
        XCTAssertEqual(reg.captureGroupNumbers(of: "c"), [])
    }
    
    func testPattern() {
        let regUtf8 = try! Regex(pattern: "(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        XCTAssertEqual(regUtf8.pattern, "(?<a>a+)(?<b>b+(?<bc>c+))(?<a>a+)")
        
        let pattern = "Cafe\u{301} du 🌍"
        let utf16CodeUnits = Array(pattern.utf16)
        let utf16bytes = utf16CodeUnits.withUnsafeBufferPointer {
            $0.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: utf16CodeUnits.count * 2) {
                UnsafeBufferPointer.init(start: $0, count: utf16CodeUnits.count * 2)
            }
        }!
        let regUtf16 = try! Regex(patternBytes: utf16bytes, encoding: .utf16LittleEndian)
        XCTAssertEqual(regUtf16.pattern, "Cafe\u{301} du 🌍")
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        let regGb18030 = try! Regex(patternBytes: gb18030Bytes, encoding: .gb18030)
        XCTAssertEqual(regGb18030.pattern, "你好")
    }
    
    func testCaptureGroups() {
        let reg = try! Regex(pattern: #"(?<name>\w+):\s+(?<id>\d+)(\s+)(//.*)"#)
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
