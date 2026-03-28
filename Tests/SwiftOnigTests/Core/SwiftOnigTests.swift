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

    final class LifetimeToken: @unchecked Sendable {
        let id: String

        init(_ id: String) {
            self.id = id
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

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

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

        let regex = try Regex(pattern: #"\A\p{SwiftOnigKana}{2}\z"#)
        #expect(try regex.matches("あい"))
        #expect(try !regex.matches("あう"))
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

        let regex = try Regex(pattern: #"\A(*swiftTestCallout)abc\z"#)
        #expect(try regex.matches("abc"))
        #expect(phases.values.contains { $0.contains("swiftTestCallout") })
    }

    @Test("Uninitialize resets runtime state for reuse")
    func uninitializeResetsRuntimeState() async throws {
        try await defineUserUnicodeProperty(
            named: "SwiftOnigResetKana",
            ranges: [OnigurumaUnicodePropertyRange(0x3042, 0x3042)]
        )
        let before = try Regex(pattern: #"\A\p{SwiftOnigResetKana}\z"#)
        #expect(try before.matches("あ"))

        let firstPhases = MessageBox()
        try await registerCallout(named: "swiftResetCallout") { context in
            firstPhases.append("before:\(context.name ?? "")")
            return .continue
        }
        let beforeCalloutRegex = try Regex(pattern: #"\A(*swiftResetCallout)ok\z"#)
        #expect(try beforeCalloutRegex.matches("ok"))
        #expect(firstPhases.values == ["before:swiftResetCallout"])

        await uninitialize()

        let after = try Regex(pattern: #"\A\p{SwiftOnigResetKana}\z"#)
        #expect(try !after.matches("あ"))
        #expect(throws: OnigError.self) {
            _ = try Regex(pattern: #"\A(*swiftResetCallout)ok\z"#)
        }

        try await defineUserUnicodeProperty(
            named: "SwiftOnigResetKana",
            ranges: [OnigurumaUnicodePropertyRange(0x3044, 0x3044)]
        )
        let redefined = try Regex(pattern: #"\A\p{SwiftOnigResetKana}\z"#)
        #expect(try !redefined.matches("あ"))
        #expect(try redefined.matches("い"))

        let secondPhases = MessageBox()
        try await registerCallout(named: "swiftResetCallout") { context in
            secondPhases.append("after:\(context.name ?? "")")
            return .continue
        }
        let afterCalloutRegex = try Regex(pattern: #"\A(*swiftResetCallout)ok\z"#)
        #expect(try afterCalloutRegex.matches("ok"))
        #expect(secondPhases.values == ["after:swiftResetCallout"])
    }

    @Test("Warning handlers reset and can be replaced after uninitialize")
    func warningHandlersResetAfterUninitialize() async throws {
        let firstStandard = MessageBox()
        let firstVerbose = MessageBox()

        await setWarningHandler { firstStandard.append("first:\($0)") }
        await setVerboseWarningHandler { firstVerbose.append("first:\($0)") }

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(!firstStandard.values.isEmpty)
        #expect(!firstVerbose.values.isEmpty)

        await uninitialize()

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(firstStandard.values.allSatisfy { $0.hasPrefix("first:") })
        #expect(firstVerbose.values.allSatisfy { $0.hasPrefix("first:") })

        let secondStandard = MessageBox()
        let secondVerbose = MessageBox()
        await setWarningHandler { secondStandard.append("second:\($0)") }
        await setVerboseWarningHandler { secondVerbose.append("second:\($0)") }

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(!secondStandard.values.isEmpty)
        #expect(!secondVerbose.values.isEmpty)
        #expect(secondStandard.values.allSatisfy { $0.hasPrefix("second:") })
        #expect(secondVerbose.values.allSatisfy { $0.hasPrefix("second:") })
        #expect(firstStandard.values.allSatisfy { $0.hasPrefix("first:") })
        #expect(firstVerbose.values.allSatisfy { $0.hasPrefix("first:") })

        await setWarningHandler(nil)
        await setVerboseWarningHandler(nil)
    }

    @Test("Warning handlers release captured values when cleared")
    func warningHandlerStorageReleasesClosures() async throws {
        var standardToken: LifetimeToken? = LifetimeToken("standard")
        weak let weakStandardToken = standardToken
        await setWarningHandler { [retained = standardToken!] _ in
            _ = retained.id
        }
        standardToken = nil
        #expect(weakStandardToken != nil)

        var verboseToken: LifetimeToken? = LifetimeToken("verbose")
        weak let weakVerboseToken = verboseToken
        await setVerboseWarningHandler { [retained = verboseToken!] _ in
            _ = retained.id
        }
        verboseToken = nil
        #expect(weakVerboseToken != nil)

        await setWarningHandler(nil)
        await setVerboseWarningHandler(nil)

        #expect(weakStandardToken == nil)
        #expect(weakVerboseToken == nil)
    }

    @Test("Named callout handlers release overwritten and reset closures")
    func namedCalloutStorageReleasesClosures() async throws {
        var firstToken: LifetimeToken? = LifetimeToken("first")
        weak let weakFirstToken = firstToken
        try await registerCallout(named: "swiftLifetimeCallout") { [retained = firstToken!] _ in
            _ = retained.id
            return .continue
        }
        firstToken = nil
        #expect(weakFirstToken != nil)

        var secondToken: LifetimeToken? = LifetimeToken("second")
        weak let weakSecondToken = secondToken
        try await registerCallout(named: "swiftLifetimeCallout") { [retained = secondToken!] _ in
            _ = retained.id
            return .continue
        }
        secondToken = nil

        #expect(weakFirstToken == nil)
        #expect(weakSecondToken != nil)

        await uninitialize()

        #expect(weakSecondToken == nil)
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

        let regex = try Regex(pattern: #"\Aa(?{swift-content}X)b\z"#)
        #expect(try "ab".firstMatch(of: regex, matchParam: matchParam) != nil)
        #expect(box.payloads.contains("payload"))
    }
}
