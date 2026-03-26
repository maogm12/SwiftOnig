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
        var regSet = try await RegexSet(regexes: [try await Regex(pattern: "a+"), try await Regex(pattern: "b+")])
        #expect(regSet.count == 2)
        
        regSet = try await RegexSet(patterns: ["a+", "b+", "c+"])
        #expect(regSet.count == 3)
        
        let gb18030Bytes: [UInt8] = [196, 227, 186, 195] // 你好
        regSet = try await RegexSet(patternsBytes: [gb18030Bytes], encoding: .gb18030)
        #expect(regSet.count == 1)
    }

    @Test("Reject mixed regex encodings")
    func rejectsMixedEncodings() async throws {
        let utf8Regex = try await Regex(pattern: "a+")
        let gb18030Regex = try await Regex(patternBytes: [196, 227, 186, 195], encoding: .gb18030)

        await #expect(throws: OnigError.invalidArgument) {
            _ = try await RegexSet(regexes: [utf8Regex, gb18030Regex])
        }
    }
    
    @Test("Property Access")
    func getter() async throws {
        let regSet = try await RegexSet(regexes: [try await Regex(pattern: "a+"), try await Regex(pattern: "b+")])
        let regex1 = regSet[0]
        #expect(try await regex1.matches("aaaa"))
        #expect(try await !regex1.matches("bbbb"))
    }

    @Test("Search")
    func search() async throws {
        let regSet = try await RegexSet(regexes: [try await Regex(pattern: "a+"), try await Regex(pattern: "b+"), try await Regex(pattern: "c+")])

        var result = try await regSet.firstMatch(in: "cccaaabbb", lead: .positionLead)!
        #expect(result.regexIndex == 2)
        #expect(result.region.range == 0..<3)
        #expect(result.region.string == "ccc")

        result = try await regSet.firstMatch(in: "cccaaabbb", lead: .regexLead)!
        #expect(result.regexIndex == 2)
        #expect(result.region.range == 0..<3)
        #expect(result.region.string == "ccc")

        result = try await regSet.firstMatch(in: "cccaaabbb", lead: .priorityToRegexOrder)!
        #expect(result.regexIndex == 0)
        #expect(result.region.range == 3..<6)
        #expect(result.region.string == "aaa")

        let gb18030Bytes1: [UInt8] = [202, 192, 189, 231] // 世界
        let gb18030Bytes2: [UInt8] = [196, 227, 186, 195] // 你好
        let regSetGb18030 = try await RegexSet(patternsBytes: [gb18030Bytes1, gb18030Bytes2],
                                          encoding: .gb18030)
        let target: [UInt8] = [196, 227, 186, 195, 163, 172, 208, 194, 202, 192, 189, 231, 163, 161] // 你好，新世界！
        result = try await regSetGb18030.firstMatch(in: target)!
        #expect(result.regexIndex == 1)
        #expect(result.region.range == 0..<4)
        #expect(result.region.string == "你好")
    }
}
