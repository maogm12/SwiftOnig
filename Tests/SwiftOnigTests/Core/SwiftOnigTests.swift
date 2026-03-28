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
        #expect(SwiftOnig.Oniguruma.version.count > 0)
    }

    @Test("Verify Copyright")
    func copyright() async throws {
        #expect(SwiftOnig.Oniguruma.copyright.count > 0)
    }

    @Test("Runtime defaults and global limits are synchronously configurable")
    func runtimeProperties() async throws {
        let originalEncoding = Oniguruma.defaultEncoding
        let originalMatchStack = Oniguruma.defaultMatchStackLimitSize
        let originalRetryInMatch = Oniguruma.defaultRetryLimitInMatch
        let originalRetryInSearch = Oniguruma.defaultRetryLimitInSearch
        let originalSubexpLimit = Oniguruma.subexpCallLimitInSearch
        let originalSubexpNest = Oniguruma.subexpCallMaxNestLevel
        let originalParseDepth = Oniguruma.parseDepthLimit

        defer {
            Oniguruma.defaultEncoding = originalEncoding
            Oniguruma.defaultMatchStackLimitSize = originalMatchStack
            Oniguruma.defaultRetryLimitInMatch = originalRetryInMatch
            Oniguruma.defaultRetryLimitInSearch = originalRetryInSearch
            Oniguruma.subexpCallLimitInSearch = originalSubexpLimit
            Oniguruma.subexpCallMaxNestLevel = originalSubexpNest
            Oniguruma.parseDepthLimit = originalParseDepth
        }

        Oniguruma.defaultEncoding = .utf8
        Oniguruma.defaultMatchStackLimitSize = 1024
        Oniguruma.defaultRetryLimitInMatch = 2048
        Oniguruma.defaultRetryLimitInSearch = 4096
        Oniguruma.subexpCallLimitInSearch = 123
        Oniguruma.subexpCallMaxNestLevel = 7
        Oniguruma.parseDepthLimit = 55

        #expect(Oniguruma.defaultEncoding == .utf8)
        #expect(Oniguruma.defaultMatchStackLimitSize == 1024)
        #expect(Oniguruma.defaultRetryLimitInMatch == 2048)
        #expect(Oniguruma.defaultRetryLimitInSearch == 4096)
        #expect(Oniguruma.subexpCallLimitInSearch == 123)
        #expect(Oniguruma.subexpCallMaxNestLevel == 7)
        #expect(Oniguruma.parseDepthLimit == 55)
    }

    @Test("Warning handler properties round-trip synchronously")
    func warningHandlerProperties() async throws {
        let standardBox = MessageBox()
        let verboseBox = MessageBox()

        Oniguruma.warningHandler = { standardBox.append("std:\($0)") }
        Oniguruma.verboseWarningHandler = { verboseBox.append("verb:\($0)") }

        #expect(Oniguruma.warningHandler != nil)
        #expect(Oniguruma.verboseWarningHandler != nil)

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(standardBox.values.contains { $0.hasPrefix("std:") })
        #expect(verboseBox.values.contains { $0.hasPrefix("verb:") })

        Oniguruma.warningHandler = nil
        Oniguruma.verboseWarningHandler = nil

        #expect(Oniguruma.warningHandler == nil)
        #expect(Oniguruma.verboseWarningHandler == nil)
    }

    @Test("Capture standard and verbose warnings")
    func warnings() async throws {
        let standardMessages = MessageBox()
        let verboseMessages = MessageBox()

        Oniguruma.warningHandler = { standardMessages.append($0) }
        Oniguruma.verboseWarningHandler = { verboseMessages.append($0) }

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(standardMessages.values.contains { $0.localizedCaseInsensitiveContains("character class") || $0.localizedCaseInsensitiveContains("escaped") })
        #expect(verboseMessages.values.contains { $0.localizedCaseInsensitiveContains("nested repeat") })

        Oniguruma.warningHandler = nil
        Oniguruma.verboseWarningHandler = nil
    }

    @Test("Define user Unicode property")
    func userUnicodeProperty() async throws {
        try Oniguruma.defineUnicodeProperty(
            named: "SwiftOnigKana",
            scalarRanges: [
                Unicode.Scalar(0x3042)! ... Unicode.Scalar(0x3042)!,
                Unicode.Scalar(0x3044)! ... Unicode.Scalar(0x3044)!,
            ]
        )

        let regex = try Regex(pattern: #"\A\p{SwiftOnigKana}{2}\z"#)
        #expect(try regex.matches("あい"))
        #expect(try !regex.matches("あう"))
    }

    @Test("Reject invalid user Unicode property definitions")
    func invalidUserUnicodeProperty() async throws {
        #expect(throws: OnigError.invalidArgument) {
            try Oniguruma.defineUnicodeProperty(named: "", scalarRanges: [Unicode.Scalar(0x3042)! ... Unicode.Scalar(0x3042)!])
        }

        #expect(throws: OnigError.invalidArgument) {
            try Oniguruma.defineUnicodeProperty(named: "名前", scalarRanges: [Unicode.Scalar(0x3042)! ... Unicode.Scalar(0x3042)!])
        }

        #expect(throws: OnigError.invalidArgument) {
            try Oniguruma.defineUnicodeProperty(named: "SwiftOnigEmpty", scalarRanges: [])
        }

        #expect(throws: OnigError.invalidArgument) {
            try Oniguruma.defineUnicodeProperty(
                named: "SwiftOnigOverlap",
                scalarRanges: [
                    Unicode.Scalar(0x3042)! ... Unicode.Scalar(0x3044)!,
                    Unicode.Scalar(0x3044)! ... Unicode.Scalar(0x3046)!,
                ]
            )
        }
    }

    @Test("Named callout registration")
    func namedCallout() async throws {
        let phases = MessageBox()
        try Oniguruma.registerCallout(named: "swiftTestCallout") { context in
            phases.append("\(context.phase):\(context.name ?? "")")
            return .continue
        }

        let regex = try Regex(pattern: #"\A(*swiftTestCallout)abc\z"#)
        #expect(try regex.matches("abc"))
        #expect(phases.values.contains { $0.contains("swiftTestCallout") })
    }

    @Test("Repeated initialize calls are idempotent")
    func repeatedInitializeIsIdempotent() async throws {
        try Oniguruma.initialize(encodings: [Encoding.utf8, .utf8, .gb18030])
        try Oniguruma.initialize(encodings: [Encoding.gb18030, .utf8])
        try Oniguruma.initialize(encodings: [Encoding]())

        let utf8Regex = try Regex(pattern: #"\A\d+\z"#)
        #expect(try utf8Regex.matches("123"))

        let gb18030Pattern: [UInt8] = [196, 227, 186, 195]
        let gb18030Regex = try Regex(patternBytes: gb18030Pattern, encoding: .gb18030)
        let input: [UInt8] = [196, 227, 186, 195, 163, 172]
        #expect(try gb18030Regex.firstMatch(in: input) != nil)
    }

    @Test("Explicit initialize remains valid after sync regex bootstrap")
    func explicitInitializeAfterAutoBootstrap() async throws {
        let autoBootstrapped = try Regex(pattern: #"\Aabc\z"#)
        #expect(try autoBootstrapped.matches("abc"))

        try Oniguruma.initialize(encodings: [Encoding.utf8, .utf16LittleEndian, .gb18030])

        let utf16Pattern = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
        let utf16Regex = try Regex(patternBytes: utf16Pattern, encoding: .utf16LittleEndian)
        let utf16Input = Array("prefix 你好 suffix".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
        #expect(try utf16Regex.firstMatch(in: utf16Input) != nil)

        let gb18030Pattern: [UInt8] = [196, 227, 186, 195]
        let gb18030Regex = try Regex(patternBytes: gb18030Pattern, encoding: .gb18030)
        let gb18030Input: [UInt8] = [196, 227, 186, 195, 163, 172]
        #expect(try gb18030Regex.firstMatch(in: gb18030Input) != nil)
    }

    @Test("Explicit initialize works after uninitialize")
    func explicitInitializeAfterReset() async throws {
        _ = try Regex(pattern: #"\Afoo\z"#)
        Oniguruma.uninitialize()

        try Oniguruma.initialize(encodings: [Encoding.utf8, .utf16LittleEndian])

        let utf8Regex = try Regex(pattern: #"\Abar\z"#)
        #expect(try utf8Regex.matches("bar"))

        let utf16Pattern = Array("世界".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
        let utf16Regex = try Regex(patternBytes: utf16Pattern, encoding: .utf16LittleEndian)
        let utf16Input = Array("你好世界".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
        #expect(try utf16Regex.firstMatch(in: utf16Input) != nil)
    }

    @Test("Uninitialize resets runtime state for reuse")
    func uninitializeResetsRuntimeState() async throws {
        try Oniguruma.defineUnicodeProperty(
            named: "SwiftOnigResetKana",
            scalarRanges: [Unicode.Scalar(0x3042)! ... Unicode.Scalar(0x3042)!]
        )
        let before = try Regex(pattern: #"\A\p{SwiftOnigResetKana}\z"#)
        #expect(try before.matches("あ"))

        let firstPhases = MessageBox()
        try Oniguruma.registerCallout(named: "swiftResetCallout") { context in
            firstPhases.append("before:\(context.name ?? "")")
            return .continue
        }
        let beforeCalloutRegex = try Regex(pattern: #"\A(*swiftResetCallout)ok\z"#)
        #expect(try beforeCalloutRegex.matches("ok"))
        #expect(firstPhases.values == ["before:swiftResetCallout"])

        Oniguruma.uninitialize()

        let after = try Regex(pattern: #"\A\p{SwiftOnigResetKana}\z"#)
        #expect(try !after.matches("あ"))
        #expect(throws: OnigError.self) {
            _ = try Regex(pattern: #"\A(*swiftResetCallout)ok\z"#)
        }

        try Oniguruma.defineUnicodeProperty(
            named: "SwiftOnigResetKana",
            scalarRanges: [Unicode.Scalar(0x3044)! ... Unicode.Scalar(0x3044)!]
        )
        let redefined = try Regex(pattern: #"\A\p{SwiftOnigResetKana}\z"#)
        #expect(try !redefined.matches("あ"))
        #expect(try redefined.matches("い"))

        let secondPhases = MessageBox()
        try Oniguruma.registerCallout(named: "swiftResetCallout") { context in
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

        Oniguruma.warningHandler = { firstStandard.append("first:\($0)") }
        Oniguruma.verboseWarningHandler = { firstVerbose.append("first:\($0)") }

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(!firstStandard.values.isEmpty)
        #expect(!firstVerbose.values.isEmpty)

        Oniguruma.uninitialize()

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(firstStandard.values.allSatisfy { $0.hasPrefix("first:") })
        #expect(firstVerbose.values.allSatisfy { $0.hasPrefix("first:") })

        let secondStandard = MessageBox()
        let secondVerbose = MessageBox()
        Oniguruma.warningHandler = { secondStandard.append("second:\($0)") }
        Oniguruma.verboseWarningHandler = { secondVerbose.append("second:\($0)") }

        _ = try Regex(pattern: "[a-b-c]")
        _ = try Regex(pattern: "(?:a*)+")

        #expect(!secondStandard.values.isEmpty)
        #expect(!secondVerbose.values.isEmpty)
        #expect(secondStandard.values.allSatisfy { $0.hasPrefix("second:") })
        #expect(secondVerbose.values.allSatisfy { $0.hasPrefix("second:") })
        #expect(firstStandard.values.allSatisfy { $0.hasPrefix("first:") })
        #expect(firstVerbose.values.allSatisfy { $0.hasPrefix("first:") })

        Oniguruma.warningHandler = nil
        Oniguruma.verboseWarningHandler = nil
    }

    @Test("Warning handlers release captured values when cleared")
    func warningHandlerStorageReleasesClosures() async throws {
        var standardToken: LifetimeToken? = LifetimeToken("standard")
        weak let weakStandardToken = standardToken
        Oniguruma.warningHandler = { [retained = standardToken!] _ in
            _ = retained.id
        }
        standardToken = nil
        #expect(weakStandardToken != nil)

        var verboseToken: LifetimeToken? = LifetimeToken("verbose")
        weak let weakVerboseToken = verboseToken
        Oniguruma.verboseWarningHandler = { [retained = verboseToken!] _ in
            _ = retained.id
        }
        verboseToken = nil
        #expect(weakVerboseToken != nil)

        Oniguruma.warningHandler = nil
        Oniguruma.verboseWarningHandler = nil

        #expect(weakStandardToken == nil)
        #expect(weakVerboseToken == nil)
    }

    @Test("Named callout handlers release overwritten and reset closures")
    func namedCalloutStorageReleasesClosures() async throws {
        var firstToken: LifetimeToken? = LifetimeToken("first")
        weak let weakFirstToken = firstToken
        try Oniguruma.registerCallout(named: "swiftLifetimeCallout") { [retained = firstToken!] _ in
            _ = retained.id
            return .continue
        }
        firstToken = nil
        #expect(weakFirstToken != nil)

        var secondToken: LifetimeToken? = LifetimeToken("second")
        weak let weakSecondToken = secondToken
        try Oniguruma.registerCallout(named: "swiftLifetimeCallout") { [retained = secondToken!] _ in
            _ = retained.id
            return .continue
        }
        secondToken = nil

        #expect(weakFirstToken == nil)
        #expect(weakSecondToken != nil)

        Oniguruma.uninitialize()

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
