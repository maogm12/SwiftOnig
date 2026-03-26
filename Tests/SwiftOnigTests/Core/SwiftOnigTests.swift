//
//  SwiftOnigTests.swift
//  
//
//  Created by Guangming Mao on 4/1/21.
//

import Testing
import SwiftOnig

@Suite("SwiftOnig Global Tests")
struct SwiftOnigTests {
    @Test("Verify Version")
    func version() async throws {
        #expect(SwiftOnig.version().count > 0)
    }

    @Test("Verify Copyright")
    func copyright() async throws {
        #expect(SwiftOnig.copyright().count > 0)
    }
}
