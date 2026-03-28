//
//  OnigOfficialTests.swift
//  
//
//  Created by Guangming Mao on 3/25/26.
//

@_spi(Experimental) import Testing
import SwiftOnig
import Foundation

@Suite("Official Oniguruma Tests", .serialized)
struct OnigOfficialTests {
    
    // MARK: DSL
    
    struct PatternInput {
        let pattern: String
        let input: String
        let syntax: Syntax?
        let options: Regex.Options
    }
    
    enum TestExpectation {
        case match(pattern: String, input: String, range: Range<Int>, group: Int = 0, syntax: Syntax?, options: Regex.Options)
        case noMatch(pattern: String, input: String, syntax: Syntax?, options: Regex.Options)
        case error(pattern: String, error: OnigError, syntax: Syntax?, options: Regex.Options)
    }
    
    @Test("UTF-8 Suite (test_utf8.c)")
    func utf8() async throws {
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
            "あ.*ん" =~ "あいうえおん" == 0..<18,
            
            // Anchors
            "^a" =~ "a" == 0..<1,
            "^a" =~ "ba" !~ "",
            "a$" =~ "a" == 0..<1,
            "a$" =~ "ab" !~ "",
            
            // Errors
            "[" !! .prematureEndOfCharClass,
            "(abc" !! .endPatternWithUnmatchedParenthesis,
        ])
    }

    @Test("Syntax Suite (test_syntax.c)")
    func syntax() async throws {
        let java = Syntax.java
        let posix = Syntax.posixExtended
        
        await verify([
            // Java syntax
            ("a{1,3}?" =~ "aaa" == 0..<1).with(syntax: java),
            ("a{1,3}?" =~ "aaa" == 0..<1).with(syntax: java),
            
            // POSIX Extended
            ("(a)b" =~ "ab" == 0..<2).with(syntax: posix),
            ("(a)b" =~ "ab" == (group: 1, 0..<1)).with(syntax: posix),
        ])
    }

    @Test("Options Suite (test_options.c)")
    func options() async throws {
        await verify([
            ("a" =~ "A" == 0..<1).with(options: .ignoreCase),
            ("abc" =~ "ABC" == 0..<3).with(options: .ignoreCase),
            ("a.*b" =~ "a\nb" == 0..<3).with(options: .multiLine),
        ])
    }

    @Test("Backtracking & Recursion (test_back.c)")
    func back() async throws {
        await verify([
            // Atomic groups
            "(?>a+)aa" =~ "aaaaa" !~ "",
            "(?>a+)a" =~ "aaaaa" !~ "",
            
            // Lookahead
            "a(?=b)" =~ "ab" == 0..<1,
            "a(?=b)" =~ "ac" !~ "",
            "a(?!b)" =~ "ac" == 0..<1,
            "a(?!b)" =~ "ab" !~ "",
            
            // Recursion
            #"(?<p>\(\g<p>*\))"# =~ "(())" == 0..<4,
            #"(?<p>\(\g<p>*\))"# =~ "((()))" == 0..<6,
        ])
    }
    
    // MARK: Verification Engine
    
    private func verify(_ expectations: [TestExpectation]) async {
        for expectation in expectations {
            switch expectation {
            case .match(let pattern, let input, let expectedRange, let group, let syntax, let options):
                do {
                    let reg = try Regex(pattern: pattern, options: options, syntax: syntax)
                    guard let region = try reg.firstMatch(in: Array(input.utf8)) else {
                        Issue.record("Pattern /\(pattern)/ failed to match '\(input)'")
                        continue
                    }
                    #expect(region[group]?.byteRange == expectedRange, "Pattern /\(pattern)/ matched wrong range in '\(input)' for group \(group)")
                } catch {
                    Issue.record("Pattern /\(pattern)/ threw error: \(error)")
                }
                
            case .noMatch(let pattern, let input, let syntax, let options):
                do {
                    let reg = try Regex(pattern: pattern, options: options, syntax: syntax)
                    let region = try reg.firstMatch(in: Array(input.utf8))
                    #expect(region == nil, "Pattern /\(pattern)/ unexpectedly matched '\(input)'")
                } catch {
                    Issue.record("Pattern /\(pattern)/ threw error: \(error)")
                }
                
            case .error(let pattern, let expectedError, let syntax, let options):
                do {
                    _ = try Regex(pattern: pattern, options: options, syntax: syntax)
                    Issue.record("Pattern /\(pattern)/ unexpectedly succeeded")
                } catch let error as OnigError {
                    #expect(error == expectedError, "Pattern /\(pattern)/ threw wrong error")
                } catch {
                    Issue.record("Pattern /\(pattern)/ threw non-OnigError: \(error)")
                }
            }
        }
    }
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
    return OnigOfficialTests.PatternInput(pattern: lhs, input: rhs, syntax: nil, options: .none)
}

func == (lhs: OnigOfficialTests.PatternInput, rhs: Range<Int>) -> OnigOfficialTests.TestExpectation {
    return .match(pattern: lhs.pattern, input: lhs.input, range: rhs, syntax: lhs.syntax, options: lhs.options)
}

func == (lhs: OnigOfficialTests.PatternInput, rhs: (group: Int, range: Range<Int>)) -> OnigOfficialTests.TestExpectation {
    return .match(pattern: lhs.pattern, input: lhs.input, range: rhs.range, group: rhs.group, syntax: lhs.syntax, options: lhs.options)
}

func !~ (lhs: OnigOfficialTests.PatternInput, rhs: String) -> OnigOfficialTests.TestExpectation {
    return .noMatch(pattern: lhs.pattern, input: lhs.input, syntax: lhs.syntax, options: lhs.options)
}

func !! (lhs: String, rhs: OnigError) -> OnigOfficialTests.TestExpectation {
    return .error(pattern: lhs, error: rhs, syntax: nil, options: .none)
}

extension OnigOfficialTests.PatternInput {
    func with(syntax: Syntax) -> OnigOfficialTests.PatternInput {
        return OnigOfficialTests.PatternInput(pattern: self.pattern, input: self.input, syntax: syntax, options: self.options)
    }
    func with(options: Regex.Options) -> OnigOfficialTests.PatternInput {
        return OnigOfficialTests.PatternInput(pattern: self.pattern, input: self.input, syntax: self.syntax, options: options)
    }
}

extension OnigOfficialTests.TestExpectation {
    func with(syntax: Syntax) -> OnigOfficialTests.TestExpectation {
        switch self {
        case .match(let p, let i, let r, let g, _, let o): return .match(pattern: p, input: i, range: r, group: g, syntax: syntax, options: o)
        case .noMatch(let p, let i, _, let o): return .noMatch(pattern: p, input: i, syntax: syntax, options: o)
        case .error(let p, let e, _, let o): return .error(pattern: p, error: e, syntax: syntax, options: o)
        }
    }
    func with(options: Regex.Options) -> OnigOfficialTests.TestExpectation {
        switch self {
        case .match(let p, let i, let r, let g, let s, _): return .match(pattern: p, input: i, range: r, group: g, syntax: s, options: options)
        case .noMatch(let p, let i, let s, _): return .noMatch(pattern: p, input: i, syntax: s, options: options)
        case .error(let p, let e, let s, _): return .error(pattern: p, error: e, syntax: s, options: options)
        }
    }
}
