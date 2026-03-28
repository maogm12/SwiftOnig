//
//  ErrorTests.swift
//  
//
//  Created by Guangming Mao on 4/13/21.
//

import Testing
import SwiftOnig

@Suite("OnigError Tests")
struct OnigErrorTests {
    @Test("Verify regex compilation errors")
    func errorHandling() async throws {
        #expect(throws: OnigError.tooBigNumberForRepeatRange) {
            _ = try Regex(pattern: "a{3,999999999999999999999999999999999999999999}")
        }
        
        do {
            _ = try Regex(pattern: #"(?<$$$>\d+)"#)
            Issue.record("Should have thrown invalidCharInGroupName")
        } catch OnigError.invalidCharInGroupName {
            // Success
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
