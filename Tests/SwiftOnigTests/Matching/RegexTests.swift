//
//  RegexTests.swift
//  
//
//  Created by Guangming Mao on 4/1/21.
//

import Testing
import Foundation
import OnigurumaC
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

    @Test("MatchParam support on core search and match APIs")
    func matchParamSupport() async throws {
        let regex = try await Regex(pattern: "(a|aa)+b")
        let target = String(repeating: "a", count: 24)
        let matchParam = MatchParam()
        matchParam.setRetryLimitInMatch(to: 1)
        matchParam.setRetryLimitInSearch(to: 1)

        func expectRetryLimitError(_ body: () async throws -> Void) async {
            do {
                try await body()
                Issue.record("Expected retry limit error")
            } catch let error as OnigError {
                #expect(error == .retryLimitInMatchOver || error == .retryLimitInSearchOver)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        await expectRetryLimitError {
            _ = try await regex.matchCount(in: target, matchParam: matchParam)
        }

        await expectRetryLimitError {
            _ = try await regex.matches(target, matchParam: matchParam)
        }

        await expectRetryLimitError {
            _ = try await regex.firstMatch(in: target, matchParam: matchParam)
        }
    }

    @Test("Compile and search option flags")
    func optionFlags() async throws {
        let defaultWordRegex = try await Regex(pattern: #"^\w+$"#)
        let asciiWordRegex = try await Regex(pattern: #"^\w+$"#, options: .wordIsASCII)
        #expect(try await defaultWordRegex.matches("cafe"))
        #expect(try await defaultWordRegex.matches("café"))
        #expect(try await !asciiWordRegex.matches("café"))

        let unicodeIgnoreCase = try await Regex(pattern: "é", options: .ignoreCase)
        let asciiIgnoreCase = try await Regex(pattern: "é", options: [.ignoreCase, .ignoreCaseIsASCII])
        #expect(try await unicodeIgnoreCase.matches("É"))
        #expect(try await !asciiIgnoreCase.matches("É"))

        let wholeMatchRegex = try await Regex(pattern: #"foo"#)
        #expect(try await wholeMatchRegex.firstMatch(in: "foo bar", options: .matchWholeString) == nil)
        #expect(try await wholeMatchRegex.firstMatch(in: "foo", options: .matchWholeString) != nil)

        #expect(Regex.SearchOptions.callbackEachMatch.rawValue == ONIG_OPTION_CALLBACK_EACH_MATCH)
        #expect(Regex.Options.digitIsASCII.rawValue == ONIG_OPTION_DIGIT_IS_ASCII)
        #expect(Regex.Options.spaceIsASCII.rawValue == ONIG_OPTION_SPACE_IS_ASCII)
        #expect(Regex.Options.posixIsASCII.rawValue == ONIG_OPTION_POSIX_IS_ASCII)
        #expect(Regex.Options.textSegmentExtendedGraphemeCluster.rawValue == ONIG_OPTION_TEXT_SEGMENT_EXTENDED_GRAPHEME_CLUSTER)
        #expect(Regex.Options.textSegmentWord.rawValue == ONIG_OPTION_TEXT_SEGMENT_WORD)
    }

    @Test("Whole match convenience")
    func wholeMatch() async throws {
        let regex = try await Regex(pattern: #"foo"#)
        let matchParam = MatchParam()
        matchParam.setRetryLimitInSearch(to: 1_000)

        let full = try await regex.wholeMatch(in: "foo", matchParam: matchParam)
        #expect(full?[0]?.string == "foo")
        #expect(try await regex.wholeMatch(in: "foo bar") == nil)
        #expect(try await regex.wholeMatch(in: "bar foo") == nil)
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
