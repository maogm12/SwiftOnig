//
//  ErrorTests.swift
//  
//
//  Created by Gavin Mao on 4/13/21.
//

import Testing
import SwiftOnig

@Suite("OnigError Tests")
struct OnigErrorTests {
    @Test("Verify regex compilation errors")
    func errorHandling() async throws {
        await #expect(throws: OnigError.tooBigNumberForRepeatRange) {
            _ = try await Regex(pattern: "a{3,999999999999999999999999999999999999999999}")
        }
        
        do {
            _ = try await Regex(pattern: #"(?<$$$>\d+)"#)
            Issue.record("Should have thrown invalidCharInGroupName")
        } catch OnigError.invalidCharInGroupName {
            // Success
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
