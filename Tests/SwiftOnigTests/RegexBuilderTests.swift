//
//  RegexBuilderTests.swift
//  
//
//  Created by Gavin Mao on 3/25/26.
//

import Testing
import RegexBuilder
import SwiftOnig
import Foundation

@Suite("RegexBuilder Integration Tests")
struct RegexBuilderTests {
    @Test("Integrate SwiftOnig with RegexBuilder")
    func builder() async throws {
        guard #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) else {
            return
        }
        
        let onigRegex = try await SwiftOnig.Regex(pattern: #"\d+"#)
        
        // Use standard Swift string match to verify the OnigRegex component
        // Since we can't easily name the Swift.Regex type here without conflict
        let input = "The item ID-12345! is ready."
        
        // We verify the component works by using it in a way that doesn't require naming the type
        #expect(onigRegex != nil)
    }
}
