//
//  ErrorTests.swift
//  
//
//  Created by Gavin Mao on 4/13/21.
//

import XCTest
import SwiftOnig

final class OnigErrorTests: SwiftOnigTestsBase {
    func testError() async {
        await XCTAssertThrowsSpecific(try await Regex(pattern: "a{3,999999999999999999999999999999999999999999}"),
                                OnigError.tooBigNumberForRepeatRange)
        
        do {
            _ = try await Regex(pattern: #"(?<$$$>\d+)"#)
            XCTFail("Should throw")
        } catch OnigError.invalidCharInGroupName {
            // Success
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    static let allTests = [
        ("testError", testError)
    ]
}
