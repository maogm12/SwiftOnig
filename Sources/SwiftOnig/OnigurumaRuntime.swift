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
    nonisolated(unsafe) static var standardHandler: OnigurumaWarningHandler?
    nonisolated(unsafe) static var verboseHandler: OnigurumaWarningHandler?
}

private func onigurumaStandardWarningCallback(_ message: UnsafePointer<CChar>?) {
    guard let message else { return }
    OnigurumaWarningBridge.standardHandler?(String(cString: message))
}

private func onigurumaVerboseWarningCallback(_ message: UnsafePointer<CChar>?) {
    guard let message else { return }
    OnigurumaWarningBridge.verboseHandler?(String(cString: message))
}

/**
 A global actor used to synchronize access to the underlying oniguruma library's global state.
 */
@globalActor
public actor OnigurumaActor {
    public static let shared = OnigurumaActor()

    private var isLibraryInitialized = false
    private var initializedEncodings = Set<OnigEncoding>()
    private var userUnicodePropertyStorage = [ContiguousArray<OnigCodePoint>]()

    /**
     Ensures that the oniguruma library and the specified encoding are initialized.
     */
    internal func ensureInitialized(encoding: OnigEncoding? = nil) throws {
        if !isLibraryInitialized {
            onig_initialize(nil, 0)
            isLibraryInitialized = true
        }

        if let encoding = encoding, !initializedEncodings.contains(encoding) {
            let result = onig_initialize_encoding(encoding)
            if result != ONIG_NORMAL {
                throw OnigError(onigErrorCode: result)
            }
            initializedEncodings.insert(encoding)
        }
    }

    fileprivate func defineUserUnicodeProperty(named name: String, ranges: [OnigurumaUnicodePropertyRange]) throws {
        try ensureInitialized()

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

        userUnicodePropertyStorage.append(storage)
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

/**
 Initialize the library manually with specific encodings.

 - Note: This is no longer required as initialization happens automatically on first use.
 - Parameter encodings: Encodings used in the application.
 */
@OnigurumaActor
public func initialize<S: Sequence>(encodings: S) async throws where S.Element == Encoding {
    try await OnigurumaActor.shared.ensureInitialized()

    for encoding in encodings {
        try await OnigurumaActor.shared.ensureInitialized(encoding: encoding.rawValue)
    }
}

/**
 The use of this library is finished.
 - Note: It is not allowed to use regex objects which created before `uninitialize` call.
 */
@OnigurumaActor
public func uninitialize() {
    _ = onig_end()
}

/**
 Register the global standard warning handler used by Oniguruma during regex compilation.
 */
@OnigurumaActor
public func setWarningHandler(_ handler: OnigurumaWarningHandler?) {
    OnigurumaWarningBridge.standardHandler = handler
    onig_set_warn_func(onigurumaStandardWarningCallback)
}

/**
 Register the global verbose warning handler used by Oniguruma during regex compilation.
 */
@OnigurumaActor
public func setVerboseWarningHandler(_ handler: OnigurumaWarningHandler?) {
    OnigurumaWarningBridge.verboseHandler = handler
    onig_set_verb_warn_func(onigurumaVerboseWarningCallback)
}

/**
 Register a user-defined Unicode property for later use in regex patterns.
 */
@OnigurumaActor
public func defineUserUnicodeProperty(named name: String, ranges: [OnigurumaUnicodePropertyRange]) async throws {
    try await OnigurumaActor.shared.defineUserUnicodeProperty(named: name, ranges: ranges)
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
public func version() -> String {
    String(cString: onig_version())
}

/**
 Get the oniguruma library copyright string.
 */
public func copyright() -> String {
    String(cString: onig_copyright())
}
