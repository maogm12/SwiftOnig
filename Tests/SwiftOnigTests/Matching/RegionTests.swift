//
//  RegionTests.swift
//  
//
//  Created by Guangming Mao on 4/1/21.
//

import Testing
import Foundation
import OnigurumaC
@testable import SwiftOnig

@Suite("Region Tests")
struct RegionTests {
    final class AccessCountingString: @unchecked Sendable, OnigurumaString {
        private let base: String
        private let lock = NSLock()
        private(set) var accessCount = 0

        init(_ base: String) {
            self.base = base
        }

        func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
            lock.lock()
            accessCount += 1
            lock.unlock()
            return try base.withOnigurumaString(requestedEncoding: requestedEncoding) { start, count in
                try body(start, count)
            }
        }
    }

    @Test("Matched string extraction")
    func string() async throws {
        let r1 = try await Regex(pattern: "a+").firstMatch(in: "aaabbb")!
        #expect(r1.decodedString() == "aaa")
        
        let r2 = try await Regex(pattern: "b+").firstMatch(in: "aaabbb")!
        #expect(r2.decodedString() == "bbb")
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

    @Test("Range access does not eagerly decode matched strings")
    func lazySubregionStringDecoding() async throws {
        let input = AccessCountingString("aaabbbccc")
        let regex = try await Regex(pattern: "(a+)(b+)(c+)")
        let region = try await regex.firstMatch(in: input)!

        #expect(input.accessCount == 1)
        #expect(region.range == 0..<9)
        #expect(input.accessCount == 1)
        #expect(region[1]?.range == 0..<3)
        #expect(input.accessCount == 1)
        #expect(region[1]?.decodedString() == "aaa")
        #expect(input.accessCount == 2)
        #expect(region.decodedString() == "aaabbbccc")
        #expect(input.accessCount == 3)
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
        #expect(fooRegions[0].decodedString() == "aaa")
        
        let barRegions = region["bar"]
        #expect(barRegions.count == 1)
        #expect(barRegions[0].decodedString() == "bbbb")

        let bazRegions = region["baz"]
        #expect(bazRegions.count == 1)
        #expect(bazRegions[0].decodedString() == "cc")
        #expect(region.backReferencedGroupNumber(of: "bar") == 2)
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
        var syntax = Syntax(copying: Syntax.default)
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
        guard let tree = region?.captureTree else { return }

        #expect(tree.groupNumber == 0)
        #expect(tree.range == 0..<4)
        #expect(tree.hasChildren)
        #expect(tree.childrenCount == 2)
        #expect(tree.children[0].groupNumber == 1)
        #expect(tree.children[0].range == 0..<2)
        #expect(tree.children[0].hasChildren)
        #expect(tree.children[0].childrenCount == 1)
        #expect(tree.children[1].range == 2..<4)

        final class Traversal: @unchecked Sendable {
            var before = [(Int, Range<Int>, Int)]()
            var after = [(Int, Range<Int>, Int)]()
        }
        let traversal = Traversal()
        region?.enumerateCaptureTreeNodes(beforeTraversingChildren: { group, range, level in
            traversal.before.append((group, range, level))
            return true
        }, afterTraversingChildren: { group, range, level in
            traversal.after.append((group, range, level))
            return true
        })

        #expect(traversal.before.count == traversal.after.count)
        #expect(traversal.before.first?.0 == 0)
        #expect(traversal.before.first?.1 == 0..<4)
        #expect(traversal.before.contains { $0.0 == 1 && $0.1 == 0..<2 && $0.2 == 1 })
        #expect(traversal.before.contains { $0.0 == 1 && $0.1 == 2..<4 && $0.2 == 1 })
    }
}
