import OnigurumaC
import Foundation

/// A handler that receives global Oniguruma runtime warning messages.
public typealias OnigurumaWarningHandler = @Sendable (String) -> Void

private struct UserUnicodePropertyRange: Sendable, Equatable {
    let lowerBound: OnigCodePoint
    let upperBound: OnigCodePoint
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

    static func defineUnicodeProperty(named name: String, ranges: [UserUnicodePropertyRange]) throws {
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
    nonisolated(unsafe) static let ascii: OnigEncoding = get_onig_ascii()
    nonisolated(unsafe) static let iso8859_1: OnigEncoding = get_onig_iso8859_1()
    nonisolated(unsafe) static let iso8859_2: OnigEncoding = get_onig_iso8859_2()
    nonisolated(unsafe) static let iso8859_3: OnigEncoding = get_onig_iso8859_3()
    nonisolated(unsafe) static let iso8859_4: OnigEncoding = get_onig_iso8859_4()
    nonisolated(unsafe) static let iso8859_5: OnigEncoding = get_onig_iso8859_5()
    nonisolated(unsafe) static let iso8859_6: OnigEncoding = get_onig_iso8859_6()
    nonisolated(unsafe) static let iso8859_7: OnigEncoding = get_onig_iso8859_7()
    nonisolated(unsafe) static let iso8859_8: OnigEncoding = get_onig_iso8859_8()
    nonisolated(unsafe) static let iso8859_9: OnigEncoding = get_onig_iso8859_9()
    nonisolated(unsafe) static let iso8859_10: OnigEncoding = get_onig_iso8859_10()
    nonisolated(unsafe) static let iso8859_11: OnigEncoding = get_onig_iso8859_11()
    nonisolated(unsafe) static let iso8859_13: OnigEncoding = get_onig_iso8859_13()
    nonisolated(unsafe) static let iso8859_14: OnigEncoding = get_onig_iso8859_14()
    nonisolated(unsafe) static let iso8859_15: OnigEncoding = get_onig_iso8859_15()
    nonisolated(unsafe) static let iso8859_16: OnigEncoding = get_onig_iso8859_16()
    nonisolated(unsafe) static let utf8: OnigEncoding = get_onig_utf8()
    nonisolated(unsafe) static let utf16be: OnigEncoding = get_onig_utf16be()
    nonisolated(unsafe) static let utf16le: OnigEncoding = get_onig_utf16le()
    nonisolated(unsafe) static let utf32be: OnigEncoding = get_onig_utf32be()
    nonisolated(unsafe) static let utf32le: OnigEncoding = get_onig_utf32le()
    nonisolated(unsafe) static let eucjp: OnigEncoding = get_onig_eucjp()
    nonisolated(unsafe) static let euctw: OnigEncoding = get_onig_euctw()
    nonisolated(unsafe) static let euckr: OnigEncoding = get_onig_euckr()
    nonisolated(unsafe) static let euccn: OnigEncoding = get_onig_euccn()
    nonisolated(unsafe) static let sjis: OnigEncoding = get_onig_sjis()
    nonisolated(unsafe) static let koi8r: OnigEncoding = get_onig_koi8r()
    nonisolated(unsafe) static let cp1251: OnigEncoding = get_onig_cp1251()
    nonisolated(unsafe) static let big5: OnigEncoding = get_onig_big5()
    nonisolated(unsafe) static let gb18030: OnigEncoding = get_onig_gb18030()

    nonisolated(unsafe) static let asis: UnsafeMutablePointer<OnigSyntaxType> = get_onig_asis()
    nonisolated(unsafe) static let posixBasic: UnsafeMutablePointer<OnigSyntaxType> = get_onig_posix_basic()
    nonisolated(unsafe) static let posixExtended: UnsafeMutablePointer<OnigSyntaxType> = get_onig_posix_extended()
    nonisolated(unsafe) static let emacs: UnsafeMutablePointer<OnigSyntaxType> = get_onig_emacs()
    nonisolated(unsafe) static let grep: UnsafeMutablePointer<OnigSyntaxType> = get_onig_grep()
    nonisolated(unsafe) static let gnuRegex: UnsafeMutablePointer<OnigSyntaxType> = get_onig_gnu_regex()
    nonisolated(unsafe) static let java: UnsafeMutablePointer<OnigSyntaxType> = get_onig_java()
    nonisolated(unsafe) static let perl: UnsafeMutablePointer<OnigSyntaxType> = get_onig_perl()
    nonisolated(unsafe) static let perlNg: UnsafeMutablePointer<OnigSyntaxType> = get_onig_perl_ng()
    nonisolated(unsafe) static let python: UnsafeMutablePointer<OnigSyntaxType> = get_onig_python()
    nonisolated(unsafe) static let ruby: UnsafeMutablePointer<OnigSyntaxType> = get_onig_ruby()
    nonisolated(unsafe) static let oniguruma: UnsafeMutablePointer<OnigSyntaxType> = get_onig_oniguruma()
    nonisolated(unsafe) static let defaultSyntax: UnsafeMutablePointer<OnigSyntaxType> = get_onig_default_syntax()
}

/// Namespace for global Oniguruma runtime configuration and advanced integration hooks.
///
/// Most applications only need `Regex` and the string-native matching APIs. Reach for
/// `Oniguruma` when you need to prewarm encodings, customize global warning behavior,
/// register named callouts, or define custom Unicode properties.
public enum Oniguruma {
    /**
     Optionally prewarms the shared runtime with specific encodings.

     Normal library usage does not require this. SwiftOnig initializes itself automatically on
     first use, so this API is primarily for startup prewarming or tests that want deterministic
     initialization timing.
     */
    public static func initialize<S: Sequence>(encodings: S) throws where S.Element == Encoding {
        try OnigurumaRuntimeCoordinator.initialize(encodings: encodings)
    }

    /**
     Tears down the shared runtime state.

     Most applications do not need to call this. Any regex objects created before this call must
     be treated as invalid afterwards.
     */
    public static func uninitialize() {
        OnigurumaRuntimeCoordinator.uninitialize()
    }

    /**
     The global standard warning handler used by Oniguruma during regex compilation.
     
     Set this to `nil` to clear the current handler.
     */
    public static var warningHandler: OnigurumaWarningHandler? {
        get { OnigurumaWarningBridge.standardHandler() }
        set {
            OnigurumaWarningBridge.setStandardHandler(newValue)
            onig_set_warn_func(onigurumaStandardWarningCallback)
        }
    }

    /**
     The global verbose warning handler used by Oniguruma during regex compilation.
     
     Set this to `nil` to clear the current handler.
     */
    public static var verboseWarningHandler: OnigurumaWarningHandler? {
        get { OnigurumaWarningBridge.verboseHandler() }
        set {
            OnigurumaWarningBridge.setVerboseHandler(newValue)
            onig_set_verb_warn_func(onigurumaVerboseWarningCallback)
        }
    }

    /**
     Registers a user-defined Unicode property for later use in regex patterns.
     
     The property name is registered globally with the shared runtime. Ranges are interpreted as
     Unicode scalar ranges, not grapheme-cluster ranges.
     */
    public static func defineUnicodeProperty(named name: String, scalarRanges: [ClosedRange<Unicode.Scalar>]) throws {
        let ranges = scalarRanges.map {
            UserUnicodePropertyRange(lowerBound: OnigCodePoint($0.lowerBound.value),
                                     upperBound: OnigCodePoint($0.upperBound.value))
        }
        try OnigurumaRuntimeCoordinator.defineUnicodeProperty(named: name, ranges: ranges)
    }

    /// Registers a named callout that can be referenced from regex patterns.
    ///
    /// The registration is global for the current process. The handler receives raw engine
    /// byte offsets through `OnigurumaCalloutContext`.
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

    /// The upstream Oniguruma version string.
    public static var version: String {
        String(cString: onig_version())
    }

    /// The upstream Oniguruma copyright string.
    public static var copyright: String {
        String(cString: onig_copyright())
    }

    /// The process-wide default encoding used when no explicit encoding is supplied.
    public static var defaultEncoding: Encoding {
        get { Encoding(rawValue: onigenc_get_default_encoding()) }
        set { _ = onigenc_set_default_encoding(newValue.rawValue) }
    }

    /// The process-wide default match stack limit.
    public static var defaultMatchStackLimitSize: UInt {
        get { UInt(onig_get_match_stack_limit_size()) }
        set { onig_set_match_stack_limit_size(OnigUInt(newValue)) }
    }

    /// The process-wide default retry limit used while matching.
    public static var defaultRetryLimitInMatch: UInt {
        get { UInt(onig_get_retry_limit_in_match()) }
        set { onig_set_retry_limit_in_match(OnigULong(newValue)) }
    }

    /// The process-wide default retry limit used while searching.
    public static var defaultRetryLimitInSearch: UInt {
        get { UInt(onig_get_retry_limit_in_search()) }
        set { onig_set_retry_limit_in_search(OnigULong(newValue)) }
    }

    /// The global subexpression call limit used while searching.
    public static var subexpCallLimitInSearch: UInt {
        get { UInt(onig_get_subexp_call_limit_in_search()) }
        set { _ = onig_set_subexp_call_limit_in_search(OnigULong(newValue)) }
    }

    /// The global maximum nesting depth for subexpression calls.
    public static var subexpCallMaxNestLevel: Int {
        get { Int(onig_get_subexp_call_max_nest_level()) }
        set { _ = onig_set_subexp_call_max_nest_level(OnigInt(newValue)) }
    }

    /// The global parser depth limit.
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
