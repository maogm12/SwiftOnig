//
//  RegexBuilderTests.swift
//  
//
//  Created by Guangming Mao on 3/25/26.
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
        let input = "The item ID-12345! is ready."
        #expect(try await onigRegex.firstMatch(in: input)?.string == "12345")
    }

    @Test("Bridge SwiftOnig regex into Swift.Regex APIs")
    func swiftRegexInterop() async throws {
        guard #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) else {
            return
        }

        let onigRegex = try await SwiftOnig.Regex(pattern: #"\d+"#)
        let input = "The item ID-12345! is ready."

        let match = input.firstMatch(of: onigRegex.swiftRegex)
        #expect(match?.output == "12345")
    }
}
