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
        let r1 = try? Regex(pattern: "(a+)(b+)(c+)")
        #expect(r1 != nil)
        let r2 = try? Regex(pattern: "+++++")
        #expect(r2 == nil)
        
        #expect(throws: OnigError.targetOfRepeatOperatorNotSpecified) {
            _ = try Regex(pattern: "???")
        }
    }

    @Test("Basic Matching")
    func match() async throws {
        let reg = try Regex(pattern: "foo")

        #expect(try reg.matches("foo"))
        #expect(try !reg.matches("bar"))

        #expect(try reg.matchedByteCount(in: "foo") == 3)
        #expect(try reg.matchedByteCount(in: "foo bar") == 3)
        #expect(try reg.matchedByteCount(in: "afoo bar", of: 1...) == 3)
        #expect(try reg.matchedByteCount(in: "bar") == nil)
    }
    
    @Test("Search")
    func search() async throws {
        let naiveEmailReg = try Regex(pattern: #"\w+@\w+\.com"#)
        let target = "Naive email: test@example.com. :)"

        guard let match = try target.firstMatch(of: naiveEmailReg) else {
            Issue.record("Failed to match email")
            return
        }
        #expect(match.count == 1)
        #expect(match.substring == "test@example.com")
        #expect(target[match.range] == "test@example.com")
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        let regGb18030 = try Regex(patternBytes: gb18030Bytes, encoding: .gb18030)
        let gb18030String: [UInt8] = [196, 227, 186, 195, 163, 172, 202, 192, 189, 231] // 你好，世界
        guard let region2 = try regGb18030.firstMatch(in: gb18030String) else {
            Issue.record("Failed to match GB18030")
            return
        }
        #expect(region2.count == 1)
        #expect(region2[0]?.range == 0..<4)
        #expect(region2[0]?.decodedString() == "你好")
    }

    @Test("MatchParam support on core search and match APIs")
    func matchParamSupport() async throws {
        let regex = try Regex(pattern: "(a|aa)+b")
        let target = String(repeating: "a", count: 24)
        var matchParam = MatchParam()
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
            _ = try regex.matchedByteCount(in: target, matchParam: matchParam)
        }

        await expectRetryLimitError {
            _ = try regex.matches(target, matchParam: matchParam)
        }

        await expectRetryLimitError {
            _ = try target.firstMatch(of: regex, matchParam: matchParam)
        }
    }

    @Test("Compile and search option flags")
    func optionFlags() async throws {
        let defaultWordRegex = try Regex(pattern: #"^\w+$"#)
        let asciiWordRegex = try Regex(pattern: #"^\w+$"#, options: .wordIsASCII)
        #expect(try defaultWordRegex.matches("cafe"))
        #expect(try defaultWordRegex.matches("café"))
        #expect(try !asciiWordRegex.matches("café"))

        let unicodeIgnoreCase = try Regex(pattern: "é", options: .ignoreCase)
        let asciiIgnoreCase = try Regex(pattern: "é", options: [.ignoreCase, .ignoreCaseIsASCII])
        #expect(try unicodeIgnoreCase.matches("É"))
        #expect(try !asciiIgnoreCase.matches("É"))

        let wholeMatchRegex = try Regex(pattern: #"foo"#)
        #expect(try wholeMatchRegex.firstStringMatch(in: "foo bar", options: .matchWholeString) == nil)
        #expect(try wholeMatchRegex.firstStringMatch(in: "foo", options: .matchWholeString) != nil)

        #expect(Regex.SearchOptions.callbackEachMatch.rawValue == ONIG_OPTION_CALLBACK_EACH_MATCH)
        #expect(Regex.Options.digitIsASCII.rawValue == ONIG_OPTION_DIGIT_IS_ASCII)
        #expect(Regex.Options.spaceIsASCII.rawValue == ONIG_OPTION_SPACE_IS_ASCII)
        #expect(Regex.Options.posixIsASCII.rawValue == ONIG_OPTION_POSIX_IS_ASCII)
        #expect(Regex.Options.textSegmentExtendedGraphemeCluster.rawValue == ONIG_OPTION_TEXT_SEGMENT_EXTENDED_GRAPHEME_CLUSTER)
        #expect(Regex.Options.textSegmentWord.rawValue == ONIG_OPTION_TEXT_SEGMENT_WORD)
    }

    @Test("Whole match convenience")
    func wholeMatch() async throws {
        let regex = try Regex(pattern: #"foo"#)
        var matchParam = MatchParam()
        matchParam.setRetryLimitInSearch(to: 1_000)

        let full = try "foo".wholeMatch(of: regex, matchParam: matchParam)
        #expect(full?.substring == "foo")
        #expect(try "foo bar".wholeMatch(of: regex) == nil)
        #expect(try "bar foo".wholeMatch(of: regex) == nil)
    }
    
    @Test("Enumerate Matches")
    func enumerateMatches() async throws {
        let reg = try Regex(pattern: #"\d+"#)
        
        final class Results: @unchecked Sendable {
            var items = [(Int, Region)]()
        }
        let results = Results()
        
        try reg.enumerateMatches(in: "aa11bb22cc33dd44") {
            results.items.append(($1, $2))
            return true
        }

        #expect(results.items.map { $0.0 } == [2, 6, 10, 14])
        #expect(results.items.map { $0.1[0]!.range } == [2..<4, 6..<8, 10..<12, 14..<16])
        #expect(results.items.map { $0.1[0]!.decodedString() } == ["11", "22", "33", "44"])
    }

    @Test("Enumerate Matches can abort and ranges are clamped")
    func enumerateAbortAndRangeClamping() async throws {
        let regex = try Regex(pattern: #"\d+"#)

        final class Results: @unchecked Sendable {
            var items = [(Int, String)]()
        }
        let results = Results()

        let count = try regex.enumerateMatches(in: "aa11bb22cc33", of: (-20)..<200) { order, matchedIndex, region in
            results.items.append((matchedIndex, region[0]?.decodedString() ?? ""))
            return order == 0
        }

        #expect(count == Int(ONIG_ABORT))
        #expect(results.items.map(\.0) == [2, 6])
        #expect(results.items.map(\.1) == ["11", "22"])
        #expect(try regex.matches("zz11yy", in: 2..<100))
        #expect(try regex.matchedByteCount(in: "zz11yy", of: 2..<100) == 2)
    }

    @Test("Capture Groups")
    func captureGroups() async throws {
        let reg = try Regex(pattern: #"(?<name>\w+):\s+(?<id>\d+)(\s+)(//.*)"#)
        #expect(reg.captureGroupsCount == 2)
    }

    @Test("Noname group capture activity")
    func nonameGroupCaptureActivity() async throws {
        let unnamedOnlyRegex = try Regex(pattern: #"(\w+)(\d+)"#)
        #expect(unnamedOnlyRegex.nonameGroupCaptureIsActive)

        let defaultNamedRegex = try Regex(pattern: #"(?<name>\w+)(\d+)"#)
        #expect(!defaultNamedRegex.nonameGroupCaptureIsActive)

        let noUnnamedCapture = try Regex(pattern: #"(\w+)(\d+)"#, options: .dontCaptureGroup)
        #expect(!noUnnamedCapture.nonameGroupCaptureIsActive)

        var syntax = Syntax(copying: Syntax.default)
        configureCaptureOnlyNamedGroup(on: &syntax)
        let captureOnlyNamedRegex = try Regex(pattern: #"(?<name>\w+)(\d+)"#, syntax: syntax)
        #expect(!captureOnlyNamedRegex.nonameGroupCaptureIsActive)

        let optInUnnamedCapture = try Regex(pattern: #"(?<name>\w+)(\d+)"#, options: .captureGroup, syntax: syntax)
        #expect(optInUnnamedCapture.nonameGroupCaptureIsActive)
    }

    private func configureCaptureOnlyNamedGroup(on syntax: inout Syntax) {
        var behaviors = syntax.behaviors
        behaviors.insert(.captureOnlyNamedGroup)
        syntax.behaviors = behaviors
    }
}
