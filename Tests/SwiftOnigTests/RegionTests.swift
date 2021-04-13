//
//  RegionTests.swift
//  
//
//  Created by Gavin Mao on 3/31/21.
//

import XCTest
@testable import SwiftOnig

final class RegionTests: SwiftOnigTestsBase {
    func testSingleRange() {
        let regex = try! Regex(pattern: #"[\d-]+"#)
        let region = try! regex.firstMatch(in: "Phone number: 123-456-7890")!
        
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region.range, 14..<26)
        XCTAssertEqual(region.string, "123-456-7890")

        XCTAssertEqual(region[0].range, 14..<26)
        XCTAssertEqual(region[0].string, "123-456-7890")
    }
    
    func testMultiRanges() {
        let regex = try! Regex(pattern: #"(\w+)@((\w+)(\.(\w+))+)"#)
        let str = "Email: test@foo.bar.com"
        let region = try! regex.firstMatch(in: str)!
        
        XCTAssertEqual(region.count, 6)
        XCTAssertEqual(region.range, 7..<23)
        XCTAssertEqual(region.string, "test@foo.bar.com")

        XCTAssertEqual(region[0].range, 7..<23)
        XCTAssertEqual(region[0].string, "test@foo.bar.com")

        XCTAssertEqual(region[1].range, 7..<11)
        XCTAssertEqual(region[1].string, "test")

        XCTAssertEqual(region[2].range, 12..<23)
        XCTAssertEqual(region[2].string, "foo.bar.com")

        XCTAssertEqual(region[3].range, 12..<15)
        XCTAssertEqual(region[3].string, "foo")

        XCTAssertEqual(region[4].range, 19..<23)
        XCTAssertEqual(region[4].string, ".com")

        XCTAssertEqual(region[5].range, 20..<23)
        XCTAssertEqual(region[5].string, "com")
    }
    
    func testString() {
        let regex = try! Regex(pattern: #"(\w+)@((\w+)(\.(\w+))+)"#)
        let str = "Email: test@foo.bar.com"
        let region = try! regex.firstMatch(in: str)!
        
        XCTAssertEqual(region[2].string, "foo.bar.com")
    }
    
    func testIterator() {
        let regex = try! Regex(pattern: "(a+)(b+)(c+)")
        let region = try! regex.firstMatch(in: "aaaabbbbc")!

        var ranges = [Subregion]()
        for range in region {
            ranges.append(range)
        }
        
        XCTAssertEqual(ranges.map { $0.range }, [0..<9, 0..<4, 4..<8, 8..<9])
        XCTAssertEqual(ranges.map { $0.string }, ["aaaabbbbc", "aaaa", "bbbb", "c"])
    }
    
    func testRandomAccessCollection() {
        let regex = try! Regex(pattern: "(a+)(b+)(c+)")
        let region = try! regex.firstMatch(in: "aabbcc")!
        
        XCTAssertEqual(region.startIndex, 0)
        XCTAssertEqual(region.endIndex, 4)

        XCTAssertEqual(region[0].range, 0..<6)
        XCTAssertEqual(region[1].range, 0..<2)
        XCTAssertEqual(region[2].range, 2..<4)
        XCTAssertEqual(region[3].range, 4..<6)
    }
    
    func testNamedCaptureGroups() {
        let regex = try! Regex(pattern: #"(?<scheme>\w+)://(.*)\?(?<arg>\w+=\w+)&(?<arg>\w+=\w+)"#)
        let str = "API: https://foo.com/bar?arg1=v1&arg2=v2"
        let region = try! regex.firstMatch(in: str)!

        XCTAssertEqual(region["scheme"].map { $0.range }, [5..<10])
        XCTAssertEqual(region["scheme"].map { $0.string }, ["https"])
        
        XCTAssertEqual(region["arg"].map{ $0.range }, [25..<32, 33..<40])
        XCTAssertEqual(region["arg"].map{ $0.string }, ["arg1=v1","arg2=v2"])

        XCTAssertTrue(region["INVALID"].isEmpty)
    }
    
    func testCaptureTree() {
        let syntax = Syntax.ruby
        syntax.operators.insert(.atmarkCaptureHistory)
        let reg = try! Regex(pattern: #"(?@a+(?@b+))|(?@c+(?@d+))"#, syntax: syntax)
        let region = try! reg.firstMatch(in: "- cd aaabbb -")!

        XCTAssertEqual(region.count, 5)

        let tree = region.captureTree!
        XCTAssertEqual(tree.childrenCount, 1)
        XCTAssertEqual(tree.group, 0)
        XCTAssertEqual(tree.bytesRange, 2..<4)

        XCTAssertEqual(tree[0].childrenCount, 1)
        XCTAssertEqual(tree[0].group, 3)
        XCTAssertEqual(tree[0].bytesRange, 2..<4)
        
        XCTAssertEqual(tree[0][0].childrenCount, 0)
        XCTAssertEqual(tree[0][0].group, 4)
        XCTAssertEqual(tree[0][0].bytesRange, 3..<4)
        
        var before = [(Int, Range<Int>, Int)]()
        var after = [(Int, Range<Int>, Int)]()
        region.forEachCaptureTreeNode { (group, range, level) -> Bool in
            before.append((group, range, level))
            return true
        } afterTraversingChildren: { (group, range, level) -> Bool in
            after.append((group, range, level))
            return true
        }
        
        XCTAssertEqual(before.map {$0.0}, [0, 3, 4]) // group
        XCTAssertEqual(before.map {$0.1}, [2..<4, 2..<4, 3..<4]) // range
        XCTAssertEqual(before.map {$0.2}, [0, 1, 2]) // level
        
        XCTAssertEqual(after.map {$0.0}, [4, 3, 0]) // group
        XCTAssertEqual(after.map {$0.1}, [3..<4, 2..<4, 2..<4]) // range
        XCTAssertEqual(after.map {$0.2}, [2, 1, 0]) // level
    }
    
    static var allTests = [
        ("testSingleRange", testSingleRange),
        ("testMultiRanges", testMultiRanges),
        ("testIterator", testIterator),
        ("testRandomAccessCollection", testRandomAccessCollection),
        ("testCaptureTree", testCaptureTree),
    ]
}
