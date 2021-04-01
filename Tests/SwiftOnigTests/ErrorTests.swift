//
//  ErrorTests.swift
//  
//
//  Created by Gavin Mao on 4/1/21.
//

import XCTest
@testable import SwiftOnig

final class OnigErrorTests: XCTestCase {
    func testError() {
        XCTAssertThrowsSpecific(try Regex("a{3,999999999999999999999999999999999999999999}"),
                                OnigError.tooBigNumberForRepeatRange)
        
        XCTAssertThrowsSpecific(try Regex(#"(?<$$$>\d+)"#),
                                OnigError.invalidCharInGroupName("$$$"))
    }
    
    static var allTests = [
        ("testError", testError)
    ]
}
