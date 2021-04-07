//
//  RegionTests.swift
//  
//
//  Created by Gavin Mao on 3/31/21.
//

import XCTest
@testable import SwiftOnig

final class RegionTests: SwiftOnigTestsBase {
    func testResize() {
        let region =  Region()
        XCTAssertEqual(region.capacity, 0)
        
        region.reserve(capacity: 100)
        XCTAssertEqual(region.capacity, 100)
        
        let region2 = Region(with: 10)
        XCTAssertEqual(region2.capacity, 10)
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
    
    func testCaptureTree() {
        let syntax = Syntax.ruby
        syntax.operators.insert(.atmarkCaptureHistory)
        let reg = try! Regex(#"(?@a+(?@b+))|(?@c+(?@d+))"#, option: .none, syntax: syntax)
        let region = try! reg.firstMatch(in: "- cd aaabbb -")!

        XCTAssertEqual(region.count, 5)

        let tree = region.tree!
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree.group, 0)
        XCTAssertEqual(tree.utf8BytesRange, 2..<4)

        XCTAssertEqual(tree[0].count, 1)
        XCTAssertEqual(tree[0].group, 3)
        XCTAssertEqual(tree[0].utf8BytesRange, 2..<4)
        
        XCTAssertEqual(tree[0][0].count, 0)
        XCTAssertEqual(tree[0][0].group, 4)
        XCTAssertEqual(tree[0][0].utf8BytesRange, 3..<4)
        
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
        ("testResize", testResize),
        ("testIterator", testIterator),
        ("testCaptureTree", testCaptureTree),
    ]
}
