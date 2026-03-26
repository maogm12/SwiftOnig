//
//  RegexTests.swift
//  
//
//  Created by Guangming Mao on 4/1/21.
//

import Testing
import Foundation
@testable import SwiftOnig

@Suite("Regex Tests")
struct RegexTests {
    @Test("Initialization")
    func initialization() async throws {
        let r1 = try? await Regex(pattern: "(a+)(b+)(c+)")
        #expect(r1 != nil)
        let r2 = try? await Regex(pattern: "+++++")
        #expect(r2 == nil)
        
        await #expect(throws: OnigError.targetOfRepeatOperatorNotSpecified) {
            _ = try await Regex(pattern: "???")
        }
    }

    @Test("Basic Matching")
    func match() async throws {
        let reg = try await Regex(pattern: "foo")

        #expect(try await reg.matches("foo"))
        #expect(try await !reg.matches("bar"))

        #expect(try await reg.matchCount(in: "foo") == 3)
        #expect(try await reg.matchCount(in: "foo bar") == 3)
        #expect(try await reg.matchCount(in: "afoo bar", of: 1...) == 3)
        #expect(try await reg.matchCount(in: "bar") == nil)
    }
    
    @Test("Search")
    func search() async throws {
        let naiveEmailReg = try await Regex(pattern: #"\w+@\w+\.com"#)
        let target = "Naive email: test@example.com. :)"

        guard let region = try await naiveEmailReg.firstMatch(in: target) else {
            Issue.record("Failed to match email")
            return
        }
        #expect(region.count == 1)
        #expect(region[0]?.range == 13..<29)
        #expect(region[0]?.string == "test@example.com")
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        let regGb18030 = try await Regex(patternBytes: gb18030Bytes, encoding: .gb18030)
        let gb18030String: [UInt8] = [196, 227, 186, 195, 163, 172, 202, 192, 189, 231] // 你好，世界
        guard let region2 = try await regGb18030.firstMatch(in: gb18030String) else {
            Issue.record("Failed to match GB18030")
            return
        }
        #expect(region2.count == 1)
        #expect(region2[0]?.range == 0..<4)
        #expect(region2[0]?.string == "你好")
    }
    
    @Test("Enumerate Matches")
    func enumerateMatches() async throws {
        let reg = try await Regex(pattern: #"\d+"#)
        
        final class Results: @unchecked Sendable {
            var items = [(Int, Region)]()
        }
        let results = Results()
        
        try await reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            results.items.append(($1, $2))
            return true
        }

        #expect(results.items.map { $0.0 } == [2, 6, 10, 14])
        #expect(results.items.map { $0.1[0]!.range } == [2..<4, 6..<8, 10..<12, 14..<16])
        #expect(results.items.map { $0.1[0]!.string } == ["11", "22", "33", "44"])
    }

    @Test("Capture Groups")
    func captureGroups() async throws {
        let reg = try await Regex(pattern: #"(?<name>\w+):\s+(?<id>\d+)(\s+)(//.*)"#)
        #expect(reg.captureGroupsCount == 2)
    }
}
