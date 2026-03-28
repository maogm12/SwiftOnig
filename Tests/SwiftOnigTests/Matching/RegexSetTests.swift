//
//  RegexSetTests.swift
//  
//
//  Created by Guangming Mao on 4/2/21.
//


import Testing
@testable import SwiftOnig

@Suite("RegexSet Tests")
struct RegexSetTests {
    @Test("Initialization")
    func initialization() async throws {
        var regSet = try await RegexSet(regexes: [try Regex(pattern: "a+"), try Regex(pattern: "b+")])
        #expect(regSet.count == 2)
        
        regSet = try await RegexSet(patterns: ["a+", "b+", "c+"])
        #expect(regSet.count == 3)
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        regSet = try await RegexSet(patternsBytes: [gb18030Bytes], encoding: .gb18030)
        #expect(regSet.count == 1)
    }

    @Test("Reject mixed regex encodings")
    func rejectsMixedEncodings() async throws {
        let utf8Regex = try Regex(pattern: "a+")
        let gb18030Regex = try Regex(patternBytes: [196, 227, 186, 195], encoding: .gb18030)

        await #expect(throws: OnigError.invalidArgument) {
            _ = try await RegexSet(regexes: [utf8Regex, gb18030Regex])
        }
    }
    
    @Test("Property Access")
    func getter() async throws {
        let regSet = try await RegexSet(regexes: [try Regex(pattern: "a+"), try Regex(pattern: "b+")])
        let regex1 = regSet[0]
        #expect(try regex1.matches("aaaa"))
        #expect(try !regex1.matches("bbbb"))
    }

    @Test("Search")
    func search() async throws {
        let regSet = try await RegexSet(regexes: [try Regex(pattern: "a+"), try Regex(pattern: "b+"), try Regex(pattern: "c+")])

        var result = try regSet.firstSetMatch(in: "cccaaabbb", lead: .positionLead)!
        #expect(result.regexIndex == 2)
        #expect(result.region.range == 0..<3)
        #expect(result.region.decodedString() == "ccc")

        result = try regSet.firstSetMatch(in: "cccaaabbb", lead: .regexLead)!
        #expect(result.regexIndex == 2)
        #expect(result.region.range == 0..<3)
        #expect(result.region.decodedString() == "ccc")

        result = try regSet.firstSetMatch(in: "cccaaabbb", lead: .priorityToRegexOrder)!
        #expect(result.regexIndex == 0)
        #expect(result.region.range == 3..<6)
        #expect(result.region.decodedString() == "aaa")

        let gb18030Bytes1: [UInt8] = [202, 192, 189, 231] // 世界
        let gb18030Bytes2: [UInt8] = [196, 227, 186, 195] // 你好
        let regSetGb18030 = try await RegexSet(patternsBytes: [gb18030Bytes1, gb18030Bytes2],
                                          encoding: .gb18030)
        let target: [UInt8] = [196, 227, 186, 195, 163, 172, 208, 194, 202, 192, 189, 231, 163, 161] // 你好，新世界！
        result = try regSetGb18030.firstSetMatch(in: target)!
        #expect(result.regexIndex == 1)
        #expect(result.region.range == 0..<4)
        #expect(result.region.decodedString() == "你好")
    }

    @Test("Mutable operations")
    func mutations() async throws {
        var regSet = try await RegexSet(regexes: [try Regex(pattern: "a+"), try Regex(pattern: "b+")])
        try regSet.append(try Regex(pattern: "c+"))
        #expect(regSet.count == 3)
        #expect(try regSet[2].matches("ccc"))

        try regSet.replace(at: 1, with: try Regex(pattern: "bb"))
        #expect(try regSet[1].matches("bb"))
        #expect(try "bbb".wholeMatch(of: regSet[1]) == nil)

        try regSet.remove(at: 0)
        #expect(regSet.count == 2)
        #expect(try regSet.firstSetMatch(in: "bbcc")?.regexIndex == 0)
    }

    @Test("Mutable operations preserve value semantics across copies")
    func copyOnWriteMutations() async throws {
        let regexA = try Regex(pattern: "a+")
        let regexB = try Regex(pattern: "b+")
        let regexC = try Regex(pattern: "c+")

        var original = try await RegexSet(regexes: [regexA, regexB])
        let copy = original

        try original.append(regexC)
        #expect(original.count == 3)
        #expect(copy.count == 2)
        #expect(try original.firstSetMatch(in: "ccc")?.regexIndex == 2)
        #expect(try copy.firstSetMatch(in: "ccc") == nil)

        try original.replace(at: 0, with: try Regex(pattern: "aa"))
        #expect(try "aa".wholeMatch(of: original[0]) != nil)
        #expect(try "a".wholeMatch(of: copy[0]) != nil)
        #expect(try "a".wholeMatch(of: original[0]) == nil)

        try original.remove(at: 1)
        #expect(original.count == 2)
        #expect(copy.count == 2)
        #expect(try copy.firstSetMatch(in: "bbb")?.regexIndex == 1)
    }

    @Test("Reject invalid mutable operations")
    func mutationValidation() async throws {
        var regSet = try await RegexSet(regexes: [try Regex(pattern: "a+")])
        let gb18030Regex = try Regex(patternBytes: [196, 227, 186, 195], encoding: .gb18030)
        let longestRegex = try Regex(pattern: "b+", options: .findLongest)

        #expect(throws: OnigError.invalidArgument) {
            try regSet.append(gb18030Regex)
        }

        #expect(throws: OnigError.invalidArgument) {
            try regSet.append(longestRegex)
        }
    }
}
