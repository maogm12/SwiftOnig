//
//  SwiftOnigTests.swift
//  
//
//  Created by Gavin Mao on 4/12/21.
//

import XCTest
import SwiftOnig

final class SwiftOnigTests: SwiftOnigTestsBase {
    func testVersion() async {
        XCTAssertFalse(SwiftOnig.version().isEmpty)
    }
    
    func testCopyright() async {
        XCTAssertFalse(SwiftOnig.copyright().isEmpty)
    }

    static let allTests = [
        ("testVersion", testVersion),
        ("testCopyright", testCopyright),
    ]
}
