//
//  RegexSet.swift
//  
//
//  Created by Gavin Mao on 4/2/21.
//


import XCTest
@testable import SwiftOnig

final class RegexSetTests: SwiftOnigTestsBase {
    func testInit() {
        let regSet = RegexSet()
        XCTAssertTrue(regSet.isEmpty)
        
        let regSet2 = try! RegexSet([Regex(pattern: "a+"), Regex(pattern: "b+")])
        XCTAssertEqual(regSet2.count, 2)
    }
    
    func testRemoveAll() {
        let regSet = try! RegexSet([Regex(pattern: "a+"), Regex(pattern: "b+")])
        XCTAssertEqual(regSet.count, 2)

        regSet.removeAll()
        XCTAssertTrue(regSet.isEmpty)
    }
    
    func testRemove() {
        let regSet = try! RegexSet([Regex(pattern: "a+"), Regex(pattern: "b+"), Regex(pattern: "c+")])
        XCTAssertEqual(regSet.count, 3)
        XCTAssertEqual(regSet[1].pattern, "b+")
        
        regSet.remove(at: 1)
        XCTAssertEqual(regSet.count, 2)
        XCTAssertEqual(regSet[1].pattern, "c+")
    }
    
    func testAppend() {
        let regSet = RegexSet()
        XCTAssertTrue(regSet.isEmpty)
        
        try! regSet.append(Regex(pattern: "a+"))
        XCTAssertEqual(regSet.count, 1)
        
        XCTAssertThrowsSpecific(try regSet.append(Regex(pattern: "a+", options: .findLongest, syntax: Syntax.default)), OnigError.invalidArgument)
        XCTAssertEqual(regSet.count, 1)
    }
    
    func testGetterSetter() {
        let regSet = try! RegexSet([Regex(pattern: "a+"), Regex(pattern: "b+")])
        var regex1 = regSet[0]
        XCTAssertTrue(regex1.isMatch("aaaa"))
        XCTAssertFalse(regex1.isMatch("cccc"))

        try! regSet.replace(regexAt: 0, with: try! Regex(pattern: "c+"))
        regex1 = regSet[0]
        XCTAssertFalse(regex1.isMatch("aaaa"))
        XCTAssertTrue(regex1.isMatch("cccc"))
    }
    
    func testSearch() {
        let regSet = try! RegexSet([Regex(pattern: "a+"), Regex(pattern: "b+"), Regex(pattern: "c+")])

        var result = try! regSet.search(in: "cccaaabbb", lead: .positionLead)
        XCTAssertEqual(result?.regexIndex, 2)
        XCTAssertEqual(result?.utf8BytesIndex, 0)

        result = try! regSet.search(in: "cccaaabbb", lead: .regexLead)
        XCTAssertEqual(result?.regexIndex, 2)
        XCTAssertEqual(result?.utf8BytesIndex, 0)
        
        result = try! regSet.search(in: "cccaaabbb", lead: .priorityToRegexOrder)
        XCTAssertEqual(result?.regexIndex, 0)
        XCTAssertEqual(result?.utf8BytesIndex, 3)
    }

    static var allTests = [
        ("testInit", testInit),
        ("testRemoveAll", testRemoveAll),
        ("testRemove", testRemove),
        ("testAppend", testAppend),
        ("testGetterSetter", testGetterSetter),
        ("testSearch", testSearch),
    ]
}
