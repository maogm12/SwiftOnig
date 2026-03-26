//
//  RegexBuilderTests.swift
//  
//
//  Created by Gavin Mao on 3/25/26.
//

import XCTest
import RegexBuilder
import _StringProcessing
@testable import SwiftOnig

final class RegexBuilderTests: SwiftOnigTestsBase {
    func testBuilder() async throws {
        let onigRegex = try await SwiftOnig.Regex(pattern: #"\d+"#)
        
        // Use the explicit _StringProcessing.Regex to avoid collision
        let regex = _StringProcessing.Regex {
            "ID-"
            onigRegex
            "!"
        }
        
        let input = "The item ID-12345! is ready."
        if let match = input.firstMatch(of: regex) {
            XCTAssertEqual(String(match.0), "ID-12345!")
        } else {
            XCTFail("Should have matched")
        }
    }
    
    static let allTests = [
        ("testBuilder", testBuilder),
    ]
}
