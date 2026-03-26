//
//  SwiftOnigTests.swift
//  
//
//  Created by Guangming Mao on 4/1/21.
//

import Testing
import SwiftOnig
import Foundation

@Suite("SwiftOnig Global Tests")
struct SwiftOnigTests {
    final class MessageBox: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var values = [String]()

        func append(_ value: String) {
            lock.lock()
            values.append(value)
            lock.unlock()
        }
    }

    @Test("Verify Version")
    func version() async throws {
        #expect(SwiftOnig.version().count > 0)
    }

    @Test("Verify Copyright")
    func copyright() async throws {
        #expect(SwiftOnig.copyright().count > 0)
    }

    @Test("Capture standard and verbose warnings")
    func warnings() async throws {
        let standardMessages = MessageBox()
        let verboseMessages = MessageBox()

        await setWarningHandler { standardMessages.append($0) }
        await setVerboseWarningHandler { verboseMessages.append($0) }

        _ = try await Regex(pattern: "[a-b-c]")
        _ = try await Regex(pattern: "(?:a*)+")

        #expect(standardMessages.values.contains { $0.localizedCaseInsensitiveContains("character class") || $0.localizedCaseInsensitiveContains("escaped") })
        #expect(verboseMessages.values.contains { $0.localizedCaseInsensitiveContains("nested repeat") })

        await setWarningHandler(nil)
        await setVerboseWarningHandler(nil)
    }
}
