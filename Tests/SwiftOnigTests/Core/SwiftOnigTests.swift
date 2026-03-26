//
//  SwiftOnigTests.swift
//  
//
//  Created by Guangming Mao on 4/1/21.
//

@_spi(Experimental) import Testing
import SwiftOnig
import Foundation

@Suite("SwiftOnig Global Tests", .serialized)
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

    @Test("Define user Unicode property")
    func userUnicodeProperty() async throws {
        try await defineUserUnicodeProperty(
            named: "SwiftOnigKana",
            ranges: [
                OnigurumaUnicodePropertyRange(0x3042, 0x3042), // あ
                OnigurumaUnicodePropertyRange(0x3044, 0x3044), // い
            ]
        )

        let regex = try await Regex(pattern: #"\A\p{SwiftOnigKana}{2}\z"#)
        #expect(try await regex.matches("あい"))
        #expect(try await !regex.matches("あう"))
    }

    @Test("Reject invalid user Unicode property definitions")
    func invalidUserUnicodeProperty() async throws {
        await #expect(throws: OnigError.invalidArgument) {
            try await defineUserUnicodeProperty(named: "", ranges: [OnigurumaUnicodePropertyRange(0x3042, 0x3042)])
        }

        await #expect(throws: OnigError.invalidArgument) {
            try await defineUserUnicodeProperty(named: "名前", ranges: [OnigurumaUnicodePropertyRange(0x3042, 0x3042)])
        }

        await #expect(throws: OnigError.invalidArgument) {
            try await defineUserUnicodeProperty(named: "SwiftOnigEmpty", ranges: [])
        }

        await #expect(throws: OnigError.invalidArgument) {
            try await defineUserUnicodeProperty(named: "SwiftOnigReverse", ranges: [OnigurumaUnicodePropertyRange(0x3044, 0x3042)])
        }

        await #expect(throws: OnigError.invalidArgument) {
            try await defineUserUnicodeProperty(
                named: "SwiftOnigOverlap",
                ranges: [
                    OnigurumaUnicodePropertyRange(0x3042, 0x3044),
                    OnigurumaUnicodePropertyRange(0x3044, 0x3046),
                ]
            )
        }
    }

    @Test("Named callout registration")
    func namedCallout() async throws {
        let phases = MessageBox()
        try await registerCallout(named: "swiftTestCallout") { context in
            phases.append("\(context.phase):\(context.name ?? "")")
            return .continue
        }

        let regex = try await Regex(pattern: #"\A(*swiftTestCallout)abc\z"#)
        #expect(try await regex.matches("abc"))
        #expect(phases.values.contains { $0.contains("swiftTestCallout") })
    }

    @Test("Per-match content callouts and user data")
    func contentCallout() async throws {
        final class CalloutBox: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var payloads = [String]()

            func append(_ value: String) {
                lock.lock()
                payloads.append(value)
                lock.unlock()
            }
        }

        let box = CalloutBox()
        var matchParam = MatchParam()
        matchParam.setCalloutUserData("payload")
        matchParam.setProgressCallout { context in
            if let userData = context.userData as? String {
                box.append(userData)
            }
            return .continue
        }

        let regex = try await Regex(pattern: #"\Aa(?{swift-content}X)b\z"#)
        #expect(try await regex.firstMatch(in: "ab", matchParam: matchParam) != nil)
        #expect(box.payloads.contains("payload"))
    }
}
