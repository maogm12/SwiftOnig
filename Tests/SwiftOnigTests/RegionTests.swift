//
//  RegionTests.swift
//  
//
//  Created by Gavin Mao on 4/1/21.
//

import Testing
import Foundation
@testable import SwiftOnig

@Suite("Region Tests")
struct RegionTests {
    @Test("Matched string extraction")
    func string() async throws {
        let r1 = try await Regex(pattern: "a+").firstMatch(in: "aaabbb")!
        #expect(r1.string == "aaa")
        
        let r2 = try await Regex(pattern: "b+").firstMatch(in: "aaabbb")!
        #expect(r2.string == "bbb")
    }

    @Test("Collection properties")
    func collection() async throws {
        let r1 = try await Regex(pattern: "(a+)(b+)(c+)").firstMatch(in: "aaabbbccc")!
        #expect(r1.count == 4)
        #expect(r1.range == 0..<9)
        #expect(r1.startIndex == 0)
        #expect(r1.endIndex == 4)
    }

    @Test("Single Range")
    func singleRange() async throws {
        let r1 = try await Regex(pattern: "(a+)(b+)(c+)").firstMatch(in: "aaabbbccc")!
        #expect(r1[0]?.range == 0..<9)
        #expect(r1[1]?.range == 0..<3)
        #expect(r1[2]?.range == 3..<6)
        #expect(r1[3]?.range == 6..<9)
    }

    @Test("Multi-byte Ranges")
    func multiRanges() async throws {
        let reg = try await Regex(pattern: "(你好)(世界)")
        let target = "你好世界"
        let r1 = try await reg.firstMatch(in: target)!
        #expect(r1[0]?.range == 0..<12)
        #expect(r1[1]?.range == 0..<6)
        #expect(r1[2]?.range == 6..<12)
    }
    
    @Test("Iteration")
    func iterator() async throws {
        let r1 = try await Regex(pattern: "(a+)(b+)(c+)").firstMatch(in: "aaabbbccc")!
        var count = 0
        for subregion in r1 {
            #expect(subregion != nil)
            count += 1
        }
        #expect(count == 4)
    }

    @Test("Named Capture Group Lookups")
    func namedCaptureGroups() async throws {
        let regex = try await Regex(pattern: #"(?<foo>a*)(?<bar>b*)(?<baz>c*)"#)
        let region = try await regex.firstMatch(in: "aaabbbbcc")!
        
        let fooRegions = region["foo"]
        #expect(fooRegions.count == 1)
        #expect(fooRegions[0].string == "aaa")
        
        let barRegions = region["bar"]
        #expect(barRegions.count == 1)
        #expect(barRegions[0].string == "bbbb")

        let bazRegions = region["baz"]
        #expect(bazRegions.count == 1)
        #expect(bazRegions[0].string == "cc")
    }
    
    @Test("Nil Subregions")
    func nilSubregion() async throws {
        let reg = try await Regex(pattern: "(a)|(b)")
        let r1 = try await reg.firstMatch(in: "a")!
        #expect(r1[0] != nil)
        #expect(r1[1] != nil)
        #expect(r1[2] == nil)
        
        let r2 = try await reg.firstMatch(in: "b")!
        #expect(r2[0] != nil)
        #expect(r2[1] == nil)
        #expect(r2[2] != nil)
    }
    
    @OnigurumaActor
    private func setupCaptureTreeSyntax() async -> Syntax {
        let syntax = Syntax(copying: Syntax.default)
        syntax.operators2.insert(.asteriskBraceCallout)
        return syntax
    }

    @Test("Capture Tree")
    func captureTree() async throws {
        let syntax = await setupCaptureTreeSyntax()
        
        let regex = try await Regex(pattern: #"(?@a(?@b))+"#,
                               options: .none,
                               syntax: syntax)
        
        let region = try await regex.firstMatch(in: "abab")
        #expect(region?.captureTree != nil)
    }
}
