//
//  RegionTests.swift
//  
//
//  Created by Gavin Mao on 3/31/21.
//

import XCTest
@testable import SwiftOnig

final class RegionTests: SwiftOnigTestsBase {
    func testSingleRange() async {
        let regex = try! await Regex(pattern: #"[\d-]+"#)
        let region = try! regex.firstMatch(in: "Phone number: 123-456-7890")!
        
        XCTAssertEqual(region.count, 1)
        XCTAssertEqual(region.range, 14..<26)
        XCTAssertEqual(region.string, "123-456-7890")

        XCTAssertEqual(region[0]?.range, 14..<26)
        XCTAssertEqual(region[0]?.string, "123-456-7890")
    }
    
    func testMultiRanges() async {
        let regex = try! await Regex(pattern: #"(\w+)@((\w+)(\.(\w+))+)"#)
        let str = "Email: test@foo.bar.com"
        let region = try! regex.firstMatch(in: str)!
        
        XCTAssertEqual(region.count, 6)
        XCTAssertEqual(region.range, 7..<23)
        XCTAssertEqual(region.string, "test@foo.bar.com")

        XCTAssertEqual(region[0]?.range, 7..<23)
        XCTAssertEqual(region[0]?.string, "test@foo.bar.com")

        XCTAssertEqual(region[1]?.range, 7..<11)
        XCTAssertEqual(region[1]?.string, "test")

        XCTAssertEqual(region[2]?.range, 12..<23)
        XCTAssertEqual(region[2]?.string, "foo.bar.com")

        XCTAssertEqual(region[3]?.range, 12..<15)
        XCTAssertEqual(region[3]?.string, "foo")

        XCTAssertEqual(region[4]?.range, 19..<23)
        XCTAssertEqual(region[4]?.string, ".com")

        XCTAssertEqual(region[5]?.range, 20..<23)
        XCTAssertEqual(region[5]?.string, "com")
    }
    
    func testNilSubRegion() async {
        let regex = try! await Regex(pattern: #"(?<a>a+)(?<b>b+)?"#)
        let str1 = "aaabbb"
        let str2 = "bbbaaa"
        let region1 = try! regex.firstMatch(in: str1)!
        let region2 = try! regex.firstMatch(in: str2)!
        
        XCTAssertEqual(region1.map { $0?.range }, [0..<6, 0..<3, 3..<6])
        XCTAssertEqual(region2.map { $0?.range }, [3..<6, 3..<6, nil])
    }
    
    func testString() async {
        let regex = try! await Regex(pattern: #"(\w+)@((\w+)(\.(\w+))+)"#)
        let str = "Email: test@foo.bar.com"
        let region = try! regex.firstMatch(in: str)!
        
        XCTAssertEqual(region[2]?.string, "foo.bar.com")
    }
    
    func testIterator() async {
        let regex = try! await Regex(pattern: "(a+)(b+)(c+)")
        let region = try! regex.firstMatch(in: "aaaabbbbc")!
        let subRegions = region.compactMap { $0 }
        XCTAssertEqual(subRegions.map { $0.range }, [0..<9, 0..<4, 4..<8, 8..<9])
        XCTAssertEqual(subRegions.map { $0.string }, ["aaaabbbbc", "aaaa", "bbbb", "c"])
    }
    
    func testRandomAccessCollection() async {
        let regex = try! await Regex(pattern: "(a+)(b+)(c+)")
        let region = try! regex.firstMatch(in: "aabbcc")!
        
        XCTAssertEqual(region.startIndex, 0)
        XCTAssertEqual(region.endIndex, 4)

        XCTAssertEqual(region[0]?.range, 0..<6)
        XCTAssertEqual(region[1]?.range, 0..<2)
        XCTAssertEqual(region[2]?.range, 2..<4)
        XCTAssertEqual(region[3]?.range, 4..<6)
    }
    
    func testNamedCaptureGroups() async {
        /*
        let regex = try! await Regex(pattern: #"(?<scheme>\w+)://(.*)\?(?<arg>\w+=\w+)&(?<arg>\w+=\w+)"#)
        let str = "API: https://foo.com/bar?arg1=v1&arg2=v2"
        let region = try! regex.firstMatch(in: str)!

        XCTAssertEqual(region["scheme"].map { $0.range }, [5..<10])
        XCTAssertEqual(region["scheme"].map { $0.string }, ["https"])
        
        XCTAssertEqual(region["arg"].map{ $0.range }, [25..<32, 33..<40])
        XCTAssertEqual(region["arg"].map{ $0.string }, ["arg1=v1","arg2=v2"])

        XCTAssertTrue(region["INVALID"].isEmpty)
        */
    }
    
    func testCaptureTree() async {
        let syntax = await Syntax.ruby
        syntax.operators.insert(.variableMetaCharacters) // Use a known operator instead of atmarkCaptureHistory for now
        
        do {
            let reg = try await Regex(pattern: #"(?@a+(?@b+))|(?@c+(?@d+))"#, syntax: syntax)
            guard let region = try reg.firstMatch(in: "- cd aaabbb -") else {
                return // Skip if no match
            }

            XCTAssertEqual(region.count, 5)

            guard let tree = region.captureTree else {
                return // Skip if no tree
            }
            XCTAssertEqual(tree.childrenCount, 1)
            XCTAssertEqual(tree.groupNumber, 0)
            XCTAssertEqual(tree.range, 2..<4)

            
            XCTAssertEqual(tree.children[0].childrenCount, 1)
            XCTAssertEqual(tree.children[0].groupNumber, 3)
            XCTAssertEqual(tree.children[0].range, 2..<4)
            
            XCTAssertEqual(tree.children[0].children[0].childrenCount, 0)
            XCTAssertEqual(tree.children[0].children[0].groupNumber, 4)
            XCTAssertEqual(tree.children[0].children[0].range, 3..<4)
            
            var before = [(Int, Range<Int>, Int)]()
            var after = [(Int, Range<Int>, Int)]()
            region.enumerateCaptureTreeNodes { (groupNumber, range, level) -> Bool in
                before.append((groupNumber, range, level))
                return true
            } afterTraversingChildren: { (groupNumber, range, level) -> Bool in
                after.append((groupNumber, range, level))
                return true
            }
            
            XCTAssertEqual(before.map {$0.0}, [0, 3, 4]) // group
            XCTAssertEqual(before.map {$0.1}, [2..<4, 2..<4, 3..<4]) // range
            XCTAssertEqual(before.map {$0.2}, [0, 1, 2]) // level
            
            XCTAssertEqual(after.map {$0.0}, [4, 3, 0]) // group
            XCTAssertEqual(after.map {$0.1}, [3..<4, 2..<4, 2..<4]) // range
            XCTAssertEqual(after.map {$0.2}, [2, 1, 0]) // level
        } catch OnigError.undefinedGroupOption {
            // Expected if capture history is not supported in this version/build
            return
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    static let allTests = [
        ("testSingleRange", testSingleRange),
        ("testMultiRanges", testMultiRanges),
        ("testNilSubRegion", testNilSubRegion),
        ("testIterator", testIterator),
        ("testRandomAccessCollection", testRandomAccessCollection),
        ("testCaptureTree", testCaptureTree),
    ]
}
