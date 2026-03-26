//
//  OnigOfficialTests.swift
//  
//
//  Created by Gavin Mao on 3/25/26.
//

import XCTest
import SwiftOnig

final class OnigOfficialTests: SwiftOnigTestsBase {
    
    // MARK: DSL
    
    struct PatternInput {
        let pattern: String
        let input: String
    }
    
    enum TestExpectation {
        case match(pattern: String, input: String, range: Range<Int>, group: Int = 0)
        case noMatch(pattern: String, input: String)
        case error(pattern: String, error: OnigError)
    }
    
    func testUTF8() async {
        // Ported from test_utf8.c
        await verify([
            "a" =~ "a" == 0..<1,
            "a" =~ "ba" == 1..<2,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" =~ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" == 0..<35,
            "a*b" =~ "aaab" == 0..<4,
            "a*b" =~ "b" == 0..<1,
            "abcdefghijklmnopqrstuvwxyz" =~ "abcdefghijklmnopqrstuvwxyz" == 0..<26,
            "a.*b" =~ "abcdefg x b" == 0..<11,
            "a.*b" =~ "abc\ndefg x b" == 0..<2,
            "(...)" =~ "abc" == (group: 1, 0..<3),
            "(...)" =~ "abcd" == (group: 1, 0..<3),
            "a(b)c" =~ "abc" == (group: 1, 1..<2),
            "a(b)c" =~ "abc" == 0..<3,
            "a(b)c" =~ "xabcy" == 1..<4,
            "a(b)c" =~ "xabcy" == (group: 1, 2..<3),
            "(ab|cd)ef" =~ "abcd" !~ "",
            "(ab|cd)ef" =~ "abef" == 0..<4,
            "(ab|cd)ef" =~ "cdef" == 0..<4,
            "(?:ab|cd)ef" =~ "abef" == 0..<4,
            "(?:ab|cd)ef" =~ "cdef" == 0..<4,
            "((ab))" =~ "ab" == (group: 1, 0..<2),
            "((ab))" =~ "ab" == (group: 2, 0..<2),
            "((ab))" =~ "ab" == 0..<2,
            
            // Unicode
            "あ" =~ "あ" == 0..<3,
            "あいう" =~ "あいう" == 0..<9,
            "あいう" =~ "あいう" == (group: 0, 0..<9),
            "あ.*ん" =~ "あいうえおん" == 0..<18,
            
            // Escapes
            "\\\\" =~ "\\" == 0..<1,
            "\\w" =~ "a" == 0..<1,
            "\\w" =~ "Z" == 0..<1,
            "\\w" =~ "0" == 0..<1,
            "\\w" =~ "_" == 0..<1,
            "\\W" =~ " " == 0..<1,
            "\\d" =~ "5" == 0..<1,
            "\\D" =~ "a" == 0..<1,
            "\\s" =~ " " == 0..<1,
            "\\S" =~ "a" == 0..<1,
            
            // Character classes
            "[abc]" =~ "a" == 0..<1,
            "[abc]" =~ "b" == 0..<1,
            "[abc]" =~ "c" == 0..<1,
            "[^abc]" =~ "d" == 0..<1,
            "[a-z]" =~ "m" == 0..<1,
            
            // Anchors
            "^a" =~ "a" == 0..<1,
            "^a" =~ "ba" !~ "",
            "a$" =~ "a" == 0..<1,
            "a$" =~ "ab" !~ "",
            "\\Aa" =~ "a" == 0..<1,
            "\\Aa" =~ "ba" !~ "",
            
            // Errors
            "[" !! .prematureEndOfCharClass,
            "(abc" !! .endPatternWithUnmatchedParenthesis,
        ])
    }
    
    // MARK: Verification Engine
    
    private func verify(_ expectations: [TestExpectation]) async {
        for expectation in expectations {
            switch expectation {
            case .match(let pattern, let input, let expectedRange, let group):
                do {
                    let reg = try await Regex(pattern: pattern)
                    guard let region = try await reg.firstMatch(in: input) else {
                        XCTFail("Pattern /\(pattern)/ failed to match '\(input)'")
                        continue
                    }
                    XCTAssertEqual(region[group]?.range, expectedRange, "Pattern /\(pattern)/ matched wrong range in '\(input)' for group \(group)")
                } catch {
                    XCTFail("Pattern /\(pattern)/ threw error: \(error)")
                }
                
            case .noMatch(let pattern, let input):
                do {
                    let reg = try await Regex(pattern: pattern)
                    let region = try await reg.firstMatch(in: input)
                    XCTAssertNil(region, "Pattern /\(pattern)/ unexpectedly matched '\(input)'")
                } catch {
                    XCTFail("Pattern /\(pattern)/ threw error: \(error)")
                }
                
            case .error(let pattern, let expectedError):
                do {
                    _ = try await Regex(pattern: pattern)
                    XCTFail("Pattern /\(pattern)/ unexpectedly succeeded")
                } catch let error as OnigError {
                    XCTAssertEqual(error, expectedError, "Pattern /\(pattern)/ threw wrong error")
                } catch {
                    XCTFail("Pattern /\(pattern)/ threw non-OnigError: \(error)")
                }
            }
        }
    }

    static let allTests = [
        ("testUTF8", testUTF8),
    ]
}

// MARK: Operators

precedencegroup OnigTestPrecedence {
    higherThan: ComparisonPrecedence
    associativity: left
}

infix operator =~ : OnigTestPrecedence
infix operator !~ : OnigTestPrecedence
infix operator !! : OnigTestPrecedence

func =~ (lhs: String, rhs: String) -> OnigOfficialTests.PatternInput {
    return OnigOfficialTests.PatternInput(pattern: lhs, input: rhs)
}

func == (lhs: OnigOfficialTests.PatternInput, rhs: Range<Int>) -> OnigOfficialTests.TestExpectation {
    return .match(pattern: lhs.pattern, input: lhs.input, range: rhs)
}

func == (lhs: OnigOfficialTests.PatternInput, rhs: (group: Int, range: Range<Int>)) -> OnigOfficialTests.TestExpectation {
    return .match(pattern: lhs.pattern, input: lhs.input, range: rhs.range, group: rhs.group)
}

func !~ (lhs: OnigOfficialTests.PatternInput, rhs: String) -> OnigOfficialTests.TestExpectation {
    return .noMatch(pattern: lhs.pattern, input: lhs.input)
}

func !! (lhs: String, rhs: OnigError) -> OnigOfficialTests.TestExpectation {
    return .error(pattern: lhs, error: rhs)
}
