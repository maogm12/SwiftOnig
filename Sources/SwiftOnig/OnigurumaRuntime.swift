import OnigurumaC
import Foundation

public typealias OnigurumaWarningHandler = @Sendable (String) -> Void

public struct OnigurumaUnicodePropertyRange: Sendable, Equatable {
    public let lowerBound: OnigCodePoint
    public let upperBound: OnigCodePoint

    public init(_ lowerBound: OnigCodePoint, _ upperBound: OnigCodePoint) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

private enum OnigurumaWarningBridge {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var standardHandler: OnigurumaWarningHandler?
        var verboseHandler: OnigurumaWarningHandler?
    }

    private static let state = State()

    static func setStandardHandler(_ handler: OnigurumaWarningHandler?) {
        state.lock.lock()
        state.standardHandler = handler
        state.lock.unlock()
    }

    static func standardHandler() -> OnigurumaWarningHandler? {
        state.lock.lock()
        let handler = state.standardHandler
        state.lock.unlock()
        return handler
    }

    static func setVerboseHandler(_ handler: OnigurumaWarningHandler?) {
        state.lock.lock()
        state.verboseHandler = handler
        state.lock.unlock()
    }

    static func verboseHandler() -> OnigurumaWarningHandler? {
        state.lock.lock()
        let handler = state.verboseHandler
        state.lock.unlock()
        return handler
    }

    static func standard(_ message: String) {
        state.lock.lock()
        let handler = state.standardHandler
        state.lock.unlock()
        handler?(message)
    }

    static func verbose(_ message: String) {
        state.lock.lock()
        let handler = state.verboseHandler
        state.lock.unlock()
        handler?(message)
    }

    static func reset() {
        state.lock.lock()
        state.standardHandler = nil
        state.verboseHandler = nil
        state.lock.unlock()
    }
}

private func onigurumaStandardWarningCallback(_ message: UnsafePointer<CChar>?) {
    guard let message else { return }
    OnigurumaWarningBridge.standard(String(cString: message))
}

private func onigurumaVerboseWarningCallback(_ message: UnsafePointer<CChar>?) {
    guard let message else { return }
    OnigurumaWarningBridge.verbose(String(cString: message))
}

enum OnigurumaBootstrap {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var isLibraryInitialized = false
        var initializedEncodings = Set<OnigEncoding>()
    }

    private static let state = State()

    static func ensureInitialized(encoding: OnigEncoding? = nil) throws {
        state.lock.lock()
        defer { state.lock.unlock() }

        if !state.isLibraryInitialized {
            onig_initialize(nil, 0)
            state.isLibraryInitialized = true
        }

        if let encoding, !state.initializedEncodings.contains(encoding) {
            let result = onig_initialize_encoding(encoding)
            if result != ONIG_NORMAL {
                throw OnigError(onigErrorCode: result)
            }
            state.initializedEncodings.insert(encoding)
        }
    }

    static func reset() {
        state.lock.lock()
        _ = onig_end()
        state.isLibraryInitialized = false
        state.initializedEncodings.removeAll(keepingCapacity: false)
        state.lock.unlock()
    }
}

private enum OnigurumaRuntimeCoordinator {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var userUnicodePropertyStorage = [ContiguousArray<OnigCodePoint>]()
    }

    private static let state = State()

    static func initialize<S: Sequence>(encodings: S) throws where S.Element == Encoding {
        state.lock.lock()
        defer { state.lock.unlock() }

        try OnigurumaBootstrap.ensureInitialized()
        for encoding in encodings {
            try OnigurumaBootstrap.ensureInitialized(encoding: encoding.rawValue)
        }
    }

    static func uninitialize() {
        state.lock.lock()
        defer { state.lock.unlock() }

        OnigurumaBootstrap.reset()
        state.userUnicodePropertyStorage.removeAll(keepingCapacity: false)
        OnigurumaWarningBridge.reset()
        OnigurumaCalloutRegistry.removeAll()
        onig_set_warn_func(onigurumaStandardWarningCallback)
        onig_set_verb_warn_func(onigurumaVerboseWarningCallback)
    }

    static func defineUnicodeProperty(named name: String, ranges: [OnigurumaUnicodePropertyRange]) throws {
        state.lock.lock()
        defer { state.lock.unlock() }

        try OnigurumaBootstrap.ensureInitialized()

        guard !name.isEmpty,
              name.unicodeScalars.allSatisfy(\.isASCII),
              !ranges.isEmpty else {
            throw OnigError.invalidArgument
        }

        var previousUpperBound: OnigCodePoint?
        for range in ranges {
            guard range.lowerBound <= range.upperBound else {
                throw OnigError.invalidArgument
            }

            if let previousUpperBound, range.lowerBound <= previousUpperBound {
                throw OnigError.invalidArgument
            }

            previousUpperBound = range.upperBound
        }

        var storage = ContiguousArray<OnigCodePoint>()
        storage.reserveCapacity((ranges.count * 2) + 1)
        storage.append(OnigCodePoint(ranges.count))
        for range in ranges {
            storage.append(range.lowerBound)
            storage.append(range.upperBound)
        }

        let result = storage.withUnsafeMutableBufferPointer { buffer -> OnigInt in
            onig_unicode_define_user_property(name, buffer.baseAddress)
        }

        if result != ONIG_NORMAL {
            throw OnigError(onigErrorCode: result)
        }

        state.userUnicodePropertyStorage.append(storage)
    }

    static func registerCallout(
        named name: String,
        encoding: Encoding,
        phases: OnigurumaCalloutPhaseSet,
        handler: @escaping OnigurumaCalloutHandler
    ) throws {
        state.lock.lock()
        defer { state.lock.unlock() }

        try OnigurumaBootstrap.ensureInitialized(encoding: encoding.rawValue)

        let bytes = ContiguousArray(name.utf8)
        let result = bytes.withUnsafeBufferPointer { buffer -> OnigInt in
            onig_set_callout_of_name(encoding.rawValue,
                                     ONIG_CALLOUT_TYPE_SINGLE,
                                     UnsafeMutablePointer(mutating: buffer.baseAddress),
                                     UnsafeMutablePointer(mutating: buffer.baseAddress?.advanced(by: buffer.count)),
                                     phases.rawValue,
                                     onigurumaCalloutCallback,
                                     nil,
                                     0,
                                     nil,
                                     0,
                                     nil)
        }

        if result < 0 {
            throw OnigError(onigErrorCode: result)
        }

        OnigurumaCalloutRegistry.setHandler(handler, for: name)
    }
}

internal struct OnigCGlobals {
    static var ascii: OnigEncoding { get_onig_ascii() }
    static var iso8859_1: OnigEncoding { get_onig_iso8859_1() }
    static var iso8859_2: OnigEncoding { get_onig_iso8859_2() }
    static var iso8859_3: OnigEncoding { get_onig_iso8859_3() }
    static var iso8859_4: OnigEncoding { get_onig_iso8859_4() }
    static var iso8859_5: OnigEncoding { get_onig_iso8859_5() }
    static var iso8859_6: OnigEncoding { get_onig_iso8859_6() }
    static var iso8859_7: OnigEncoding { get_onig_iso8859_7() }
    static var iso8859_8: OnigEncoding { get_onig_iso8859_8() }
    static var iso8859_9: OnigEncoding { get_onig_iso8859_9() }
    static var iso8859_10: OnigEncoding { get_onig_iso8859_10() }
    static var iso8859_11: OnigEncoding { get_onig_iso8859_11() }
    static var iso8859_13: OnigEncoding { get_onig_iso8859_13() }
    static var iso8859_14: OnigEncoding { get_onig_iso8859_14() }
    static var iso8859_15: OnigEncoding { get_onig_iso8859_15() }
    static var iso8859_16: OnigEncoding { get_onig_iso8859_16() }
    static var utf8: OnigEncoding { get_onig_utf8() }
    static var utf16be: OnigEncoding { get_onig_utf16be() }
    static var utf16le: OnigEncoding { get_onig_utf16le() }
    static var utf32be: OnigEncoding { get_onig_utf32be() }
    static var utf32le: OnigEncoding { get_onig_utf32le() }
    static var eucjp: OnigEncoding { get_onig_eucjp() }
    static var euctw: OnigEncoding { get_onig_euctw() }
    static var euckr: OnigEncoding { get_onig_euckr() }
    static var euccn: OnigEncoding { get_onig_euccn() }
    static var sjis: OnigEncoding { get_onig_sjis() }
    static var koi8r: OnigEncoding { get_onig_koi8r() }
    static var cp1251: OnigEncoding { get_onig_cp1251() }
    static var big5: OnigEncoding { get_onig_big5() }
    static var gb18030: OnigEncoding { get_onig_gb18030() }

    static var asis: UnsafeMutablePointer<OnigSyntaxType> { get_onig_asis() }
    static var posixBasic: UnsafeMutablePointer<OnigSyntaxType> { get_onig_posix_basic() }
    static var posixExtended: UnsafeMutablePointer<OnigSyntaxType> { get_onig_posix_extended() }
    static var emacs: UnsafeMutablePointer<OnigSyntaxType> { get_onig_emacs() }
    static var grep: UnsafeMutablePointer<OnigSyntaxType> { get_onig_grep() }
    static var gnuRegex: UnsafeMutablePointer<OnigSyntaxType> { get_onig_gnu_regex() }
    static var java: UnsafeMutablePointer<OnigSyntaxType> { get_onig_java() }
    static var perl: UnsafeMutablePointer<OnigSyntaxType> { get_onig_perl() }
    static var perlNg: UnsafeMutablePointer<OnigSyntaxType> { get_onig_perl_ng() }
    static var python: UnsafeMutablePointer<OnigSyntaxType> { get_onig_python() }
    static var ruby: UnsafeMutablePointer<OnigSyntaxType> { get_onig_ruby() }
    static var oniguruma: UnsafeMutablePointer<OnigSyntaxType> { get_onig_oniguruma() }
    static var defaultSyntax: UnsafeMutablePointer<OnigSyntaxType> { get_onig_default_syntax() }
}

public enum Oniguruma {
    /**
     Optionally prewarm the shared runtime with specific encodings.

     - Note: Normal library usage does not require this. SwiftOnig initializes itself automatically on first use.
     - Parameter encodings: Encodings to initialize eagerly, typically during application startup.
     */
    public static func initialize<S: Sequence>(encodings: S) throws where S.Element == Encoding {
        try OnigurumaRuntimeCoordinator.initialize(encodings: encodings)
    }

    /**
     Tear down the shared runtime state.

     - Note: Most applications do not need to call this.
     - Note: Regex objects created before `uninitialize()` must not be used afterwards.
     */
    public static func uninitialize() {
        OnigurumaRuntimeCoordinator.uninitialize()
    }

    /**
     Register the global standard warning handler used by Oniguruma during regex compilation.
     */
    public static var warningHandler: OnigurumaWarningHandler? {
        get { OnigurumaWarningBridge.standardHandler() }
        set {
            OnigurumaWarningBridge.setStandardHandler(newValue)
            onig_set_warn_func(onigurumaStandardWarningCallback)
        }
    }

    /**
     Register the global verbose warning handler used by Oniguruma during regex compilation.
     */
    public static var verboseWarningHandler: OnigurumaWarningHandler? {
        get { OnigurumaWarningBridge.verboseHandler() }
        set {
            OnigurumaWarningBridge.setVerboseHandler(newValue)
            onig_set_verb_warn_func(onigurumaVerboseWarningCallback)
        }
    }

    /**
     Register a user-defined Unicode property for later use in regex patterns.
     */
    public static func defineUnicodeProperty(named name: String, scalarRanges: [ClosedRange<Unicode.Scalar>]) throws {
        let ranges = scalarRanges.map {
            OnigurumaUnicodePropertyRange(OnigCodePoint($0.lowerBound.value), OnigCodePoint($0.upperBound.value))
        }
        try OnigurumaRuntimeCoordinator.defineUnicodeProperty(named: name, ranges: ranges)
    }

    public static func registerCallout(
        named name: String,
        encoding: Encoding = .utf8,
        phases: OnigurumaCalloutPhaseSet = .both,
        handler: @escaping OnigurumaCalloutHandler
    ) throws {
        try OnigurumaRuntimeCoordinator.registerCallout(named: name,
                                                        encoding: encoding,
                                                        phases: phases,
                                                        handler: handler)
    }

    public static var version: String {
        String(cString: onig_version())
    }

    public static var copyright: String {
        String(cString: onig_copyright())
    }

    public static var defaultEncoding: Encoding {
        get { Encoding(rawValue: onigenc_get_default_encoding()) }
        set { _ = onigenc_set_default_encoding(newValue.rawValue) }
    }

    public static var defaultMatchStackLimitSize: UInt {
        get { UInt(onig_get_match_stack_limit_size()) }
        set { onig_set_match_stack_limit_size(OnigUInt(newValue)) }
    }

    public static var defaultRetryLimitInMatch: UInt {
        get { UInt(onig_get_retry_limit_in_match()) }
        set { onig_set_retry_limit_in_match(OnigULong(newValue)) }
    }

    public static var defaultRetryLimitInSearch: UInt {
        get { UInt(onig_get_retry_limit_in_search()) }
        set { onig_set_retry_limit_in_search(OnigULong(newValue)) }
    }

    public static var subexpCallLimitInSearch: UInt {
        get { UInt(onig_get_subexp_call_limit_in_search()) }
        set { _ = onig_set_subexp_call_limit_in_search(OnigULong(newValue)) }
    }

    public static var subexpCallMaxNestLevel: Int {
        get { Int(onig_get_subexp_call_max_nest_level()) }
        set { _ = onig_set_subexp_call_max_nest_level(OnigInt(newValue)) }
    }

    public static var parseDepthLimit: UInt {
        get { UInt(onig_get_parse_depth_limit()) }
        set { _ = onig_set_parse_depth_limit(OnigUInt(newValue)) }
    }
}

/**
 Call oniguruma functions.
 - Parameters:
    - body: The closure calling oniguruma library functions
 - Throws:
    `OnigError` if `body` returns code not in following normal return codes:
    [`ONIG_NORMAL`, `ONIG_MISMATCH`, ``ONIG_NO_SUPPORT_CONFIG`, `ONIG_ABORT`]
 */
@discardableResult
internal func callOnigFunction(_ body: () throws -> OnigInt) throws -> OnigInt {
    let result = try body()

    switch result {
    case _ where result > 0:
        return result
    case ONIG_NORMAL, ONIG_MISMATCH, ONIG_NO_SUPPORT_CONFIG, ONIG_ABORT:
        return result
    default:
        throw OnigError(onigErrorCode: result)
    }
}

/**
 Get the oniguruma library version string.
 */
