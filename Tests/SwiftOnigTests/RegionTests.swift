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
        let regex = try! Regex(#"[\d-]+"#)
        let region = try! regex.firstMatch(in: "Phone number: 123-456-7890")!
        
        XCTAssertEqual(region.rangeCount, 1)
        XCTAssertEqual(region.range, 14..<26)
        XCTAssertEqual(region.range(at: 0), 14..<26)
    }
    
    func testMultiRanges() {
        let regex = try! Regex(#"(\w+)@((\w+)(\.(\w+))+)"#)
        let str = "Email: test@foo.bar.com"
        let region = try! regex.firstMatch(in: str)!
        
        XCTAssertEqual(region.rangeCount, 6)
        XCTAssertEqual(region.range, 7..<23)

        XCTAssertEqual(region.range(at: 0), 7..<23)
        XCTAssertEqual(str.subString(utf8BytesRange: 7..<23), "test@foo.bar.com")

        XCTAssertEqual(region.range(at: 1), 7..<11)
        XCTAssertEqual(str.subString(utf8BytesRange: region.range(at: 1)), "test")

        XCTAssertEqual(region.range(at: 2), 12..<23)
        XCTAssertEqual(str.subString(utf8BytesRange: region.range(at: 2)), "foo.bar.com")

        XCTAssertEqual(region.range(at: 3), 12..<15)
        XCTAssertEqual(str.subString(utf8BytesRange: region.range(at: 3)), "foo")

        XCTAssertEqual(region.range(at: 4), 19..<23)
        XCTAssertEqual(str.subString(utf8BytesRange: region.range(at: 4)), ".com")

        XCTAssertEqual(region.range(at: 5), 20..<23)
        XCTAssertEqual(str.subString(utf8BytesRange: region.range(at: 5)), "com")
    }
    
    func testIterator() {
        let regex = try! Regex("(a+)(b+)(c+)")
        let region = try! regex.firstMatch(in: "aaaabbbbc")!

        var ranges = [Range<Int>]()
        for range in region {
            ranges.append(range)
        }
        
        XCTAssertEqual(ranges, [0..<9, 0..<4, 4..<8, 8..<9])
    }
    
    func testRandomAccessCollection() {
        let regex = try! Regex("(a+)(b+)(c+)")
        let region = try! regex.firstMatch(in: "aabbcc")!
        
        XCTAssertEqual(region.startIndex, 0)
        XCTAssertEqual(region.endIndex, 4)

        XCTAssertEqual(region[0], 0..<6)
        XCTAssertEqual(region[1], 0..<2)
        XCTAssertEqual(region[2], 2..<4)
        XCTAssertEqual(region[3], 4..<6)
    }
    
    func testNamedCaptureGroups() {
        let regex = try! Regex(#"(?<scheme>\w+)://(.*)\?(?<arg>\w+=\w+)&(?<arg>\w+=\w+)"#)
        let str = "API: https://foo.com/bar?arg1=v1&arg2=v2"
        let region = try! regex.firstMatch(in: str)!

        XCTAssertEqual(region.ranges(with: "scheme"), [5..<10])
        XCTAssertEqual(region.firstRange(with: "scheme"), 5..<10)
        XCTAssertEqual(str.subString(utf8BytesRange: region.firstRange(with: "scheme")!), "https")
        
        XCTAssertEqual(region.ranges(with: "arg"), [25..<32, 33..<40])
        XCTAssertEqual(region.firstRange(with: "arg"), 25..<32)
        XCTAssertEqual(str.subString(utf8BytesRange: region.firstRange(with: "arg")!), "arg1=v1")

        XCTAssertNil(region.firstRange(with: "INVALID"))
    }
    
    func testCaptureTree() {
        let syntax = Syntax.ruby
        syntax.operators.insert(.atmarkCaptureHistory)
        let reg = try! Regex(#"(?@a+(?@b+))|(?@c+(?@d+))"#, option: .none, syntax: syntax)
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
