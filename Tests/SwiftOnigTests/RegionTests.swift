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
    
    static var allTests = [
        ("testResize", testResize),
        ("testIterator", testIterator)
    ]
}
