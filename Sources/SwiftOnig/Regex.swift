//
//  Regex.swift
//  
//
//  Created by Guangming Mao on 3/27/21.
//

import OnigurumaC
import Foundation
import _StringProcessing
import RegexBuilder

/// A compiled Oniguruma regular expression.
///
/// `Regex` is the main entry point for compiling patterns and performing raw-byte searches.
/// SwiftOnig also provides string-native convenience APIs on `String` and `Substring`
/// that wrap raw `Region` results into `Regex.Match`.
///
/// Use the string initializer when your pattern starts as Swift text:
///
/// ```swift
/// let regex = try Regex(pattern: #"\d+"#)
/// ```
///
/// Use the byte initializer when the pattern already exists in a specific encoding:
///
/// ```swift
/// let regex = try Regex(patternBytes: patternBytes, encoding: .gb18030)
/// ```
///
/// - Important: Raw search APIs on `Regex` operate in encoded byte offsets, not
///   `String.Index` values. For string-native matching, prefer `input.firstMatch(of:)`,
///   `input.matches(of:)`, and related APIs.
public struct Regex: Sendable, CustomConsumingRegexComponent {
    public typealias RegexOutput = Substring
    internal static let fullByteRange: PartialRangeFrom<Int> = 0...

    internal final class Storage: @unchecked Sendable {
        let rawValue: OnigRegex
        let patternBytes: ContiguousArray<UInt8>
        let rawSyntax: UnsafeMutablePointer<OnigSyntaxType>
        let syntax: Syntax
        let encoding: Encoding
        let options: Options
        let matchMetadata: MatchMetadata

        init<S>(patternBytes: S,
                encoding: Encoding,
                options: Options,
                syntax: Syntax) throws where S: Sequence, S.Element == UInt8 {
            let compiledPatternBytes = ContiguousArray(patternBytes)
            let rawSyntax = syntax.allocateRawValueCopy()

            var rawValue: OnigRegex?
            var error = OnigErrorInfo()
            let result = compiledPatternBytes.withUnsafeBufferPointer { bufPtr -> OnigInt in
                onig_new(&rawValue,
                         bufPtr.baseAddress,
                         bufPtr.baseAddress?.advanced(by: compiledPatternBytes.count),
                         options.rawValue,
                         encoding.rawValue,
                         rawSyntax,
                         &error)
            }

            if result != ONIG_NORMAL {
                rawSyntax.deinitialize(count: 1)
                rawSyntax.deallocate()
                throw OnigError(onigErrorCode: result, onigErrorInfo: error)
            }

            guard let rawValue else {
                rawSyntax.deinitialize(count: 1)
                rawSyntax.deallocate()
                throw OnigError.memory
            }

            let matchMetadata = Self.makeMatchMetadata(rawValue: rawValue, encoding: encoding)

            self.rawValue = rawValue
            self.patternBytes = compiledPatternBytes
            self.rawSyntax = rawSyntax
            self.syntax = syntax
            self.encoding = encoding
            self.options = options
            self.matchMetadata = matchMetadata
        }

        private static func makeMatchMetadata(rawValue: OnigRegex, encoding: Encoding) -> MatchMetadata {
            final class MatchMetadataBox: @unchecked Sendable {
                var namedCaptureGroupNumbers = [String: [Int]]()
            }

            let box = MatchMetadataBox()
            let context = ForeachNameContext(encoding: encoding) { name, numbers in
                box.namedCaptureGroupNumbers[name] = numbers
                return true
            }

            withExtendedLifetime(context) {
                let contextPtr = Unmanaged.passUnretained(context).toOpaque()
                onig_foreach_name(rawValue, onigForeachNameCallback, contextPtr)
            }

            return MatchMetadata(namedCaptureGroupNumbers: box.namedCaptureGroupNumbers)
        }

        deinit {
            onig_free(rawValue)
            rawSyntax.deinitialize(count: 1)
            rawSyntax.deallocate()
        }
    }

    private let storage: Storage

    /// A standard-library regex view of this `SwiftOnig.Regex`.
    ///
    /// This makes it easy to pass a compiled Oniguruma pattern into APIs that
    /// expect Swift's native regex type, while preserving SwiftOnig's matching
    /// behavior under the hood.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public var swiftRegex: _StringProcessing.Regex<Substring> {
        _StringProcessing.Regex { self }
    }

    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Substring)? {
        // SwiftOnig works with byte offsets.
        // We need to convert String.Index to byte offset.
        let startOffset = input.distance(from: input.startIndex, to: index)
        let endOffset = input.distance(from: input.startIndex, to: bounds.upperBound)
        
        guard let region = try self._firstMatch(in: input, of: startOffset..<endOffset, options: .none, matchConfiguration: nil) else {
            return nil
        }
        
        let matchRange = region.byteRange
        // Ensure the match starts exactly at the requested index
        guard matchRange.lowerBound == startOffset else {
            return nil
        }
        
        let matchEndIndex = input.index(input.startIndex, offsetBy: matchRange.upperBound)
        return (matchEndIndex, input[index..<matchEndIndex])
    }
    internal var rawValue: OnigRegex {
        storage.rawValue
    }

    internal var matchMetadata: MatchMetadata {
        storage.matchMetadata
    }
    
    // MARK: init & deinit
    
    /// Compiles a regex from a Swift string pattern.
    ///
    /// Swift string patterns are always compiled as UTF-8, matching the standard Swift text path.
    /// Use this initializer for normal application code where the pattern starts as a `String`
    /// or `Substring`.
    ///
    /// - Parameters:
    ///   - pattern: The regex pattern text to compile.
    ///   - options: Oniguruma compilation options that affect how the pattern is parsed.
    ///   - syntax: The syntax preset to compile under. Defaults to `Syntax.default`.
    /// - Throws: `OnigError` when compilation fails or runtime initialization cannot complete.
    public init<S>(pattern: S,
                   options: Options = .none,
                   syntax: Syntax? = nil
    ) throws where S: StringProtocol {
        try self.init(patternBytes: pattern.utf8, encoding: Encoding.utf8, options: options, syntax: syntax)
    }

    /// Compiles a regex from raw pattern bytes in an explicit encoding.
    ///
    /// Use this initializer when the pattern is already stored as bytes, or when you need exact
    /// control over the regex encoding used by Oniguruma.
    ///
    /// - Parameters:
    ///   - patternBytes: The encoded pattern bytes to compile.
    ///   - encoding: The encoding used to interpret the pattern bytes.
    ///   - options: Oniguruma compilation options that affect how the pattern is parsed.
    ///   - syntax: The syntax preset to compile under. Defaults to `Syntax.default`.
    /// - Throws: `OnigError` when compilation fails or runtime initialization cannot complete.
    public init<S>(patternBytes: S,
                   encoding: Encoding,
                   options: Options = .none,
                   syntax: Syntax? = nil
    ) throws where S: Sequence, S.Element == UInt8 {
        try OnigurumaBootstrap.ensureInitialized(encoding: encoding.rawValue)
        let actualSyntax = syntax ?? Syntax.default
        self.storage = try Storage(patternBytes: patternBytes,
                                   encoding: encoding,
                                   options: options,
                                   syntax: actualSyntax)
    }
    
    // MARK: Accessors
    
    /// The compilation options that were used to build this regex.
    public var options: Options {
        get {
            storage.options
        }
    }
    
    /// The encoding used to compile this regex and interpret raw-input searches.
    public var encoding: Encoding {
        get {
            storage.encoding
        }
    }
    
    /// The syntax snapshot used when this regex was compiled.
    public var syntax: Syntax {
        storage.syntax
    }
    
    // MARK: Match & Search
    
    /// Searches the provided input and returns the first raw match region within a byte range.
    ///
    /// The supplied range is interpreted in encoded byte offsets and is clamped to the actual
    /// encoded length of the input before searching.
    ///
    /// - Parameters:
    ///   - str: The input to search. `String` and `Substring` inputs are first adapted into the
    ///     regex encoding.
    ///   - range: The encoded byte range to search within.
    ///   - options: Search-time options such as `.notBol` or `.matchWholeString`.
    /// - Returns: The first matching `Region`, or `nil` when no match is found.
    /// - Throws: `OnigError` if the search fails.
    public func firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Region? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: range, options: options, matchConfiguration: nil)
        }
    }

    internal func _firstMatchResolved<S>(
        in str: S,
        start: UnsafePointer<OnigUChar>,
        count: Int,
        range: Range<Int>,
        options: SearchOptions,
        matchConfiguration: MatchConfiguration?
    ) throws -> Region? where S: OnigurumaString {
        let region = try Region(regex: self, str: str)
        let result = try callOnigFunction {
            if let matchConfiguration {
                return try matchConfiguration.withRawValue { rawMatchParam in
                    onig_search_with_param(self.rawValue,
                                           start,
                                           start.advanced(by: count),
                                           start.advanced(by: range.lowerBound),
                                           start.advanced(by: range.upperBound),
                                           region.rawValue,
                                           options.rawValue,
                                           rawMatchParam)
                }
            }

            return onig_search(self.rawValue,
                               start,
                               start.advanced(by: count),
                               start.advanced(by: range.lowerBound),
                               start.advanced(by: range.upperBound),
                               region.rawValue,
                               options.rawValue)
        }

        if result == ONIG_MISMATCH {
            return nil
        }

        return region
    }

    internal func _firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchConfiguration: MatchConfiguration?) throws -> Region? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try str.withOnigurumaString(requestedEncoding: self.encoding) { (start, count) throws -> Region? in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            return try _firstMatchResolved(in: str,
                                           start: start,
                                           count: count,
                                           range: range,
                                           options: options,
                                           matchConfiguration: matchConfiguration)
        }
    }
    
    /// Searches the entire input and returns the first raw match region.
    ///
    /// This is the raw-byte counterpart to `String.firstMatch(of:)`. Prefer the string-native API
    /// when you want `Substring` and `String.Index` results instead of byte offsets.
    ///
    /// - Parameters:
    ///   - str: The input to search.
    ///   - options: Search-time options such as `.notBol` or `.matchWholeString`.
    /// - Returns: The first matching `Region`, or `nil` when no match is found.
    /// - Throws: `OnigError` if the search fails.
    public func firstMatch<S>(in str: S, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil)
        }
    }

    @available(*, deprecated, message: "Use input.firstMatch(of:) or regex.firstStringMatch(in:) for String and Substring inputs.")
    public func firstMatch(in str: String, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil)
        }
    }

    @available(*, deprecated, message: "Use input.firstMatch(of:) or regex.firstStringMatch(in:) for String and Substring inputs.")
    public func firstMatch(in str: Substring, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil)
        }
    }

    /// Searches a byte range and applies per-search match configuration.
    ///
    /// Use this overload when you need custom retry limits, stack limits, or per-search
    /// progress/retraction handlers.
    public func firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Region? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: range, options: options, matchConfiguration: matchConfiguration)
        }
    }

    /// Searches the entire input and applies per-search match configuration.
    public func firstMatch<S>(in str: S, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration)
        }
    }

    @available(*, deprecated, message: "Use input.firstMatch(of:matchConfiguration:) or regex.firstStringMatch(in:matchConfiguration:) for String and Substring inputs.")
    public func firstMatch(in str: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration)
        }
    }

    @available(*, deprecated, message: "Use input.firstMatch(of:matchConfiguration:) or regex.firstStringMatch(in:matchConfiguration:) for String and Substring inputs.")
    public func firstMatch(in str: Substring, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration)
        }
    }

    /// Searches the full input and returns a region only when the regex covers the entire input.
    ///
    /// This performs a raw whole-input match in encoded byte space. For string-native whole matches,
    /// prefer `String.wholeMatch(of:)`.
    public func wholeMatch<S>(in str: S, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchConfiguration: nil)
        }
    }

    @available(*, deprecated, message: "Use input.wholeMatch(of:) or regex.wholeStringMatch(in:) for String and Substring inputs.")
    public func wholeMatch(in str: String, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchConfiguration: nil)
        }
    }

    @available(*, deprecated, message: "Use input.wholeMatch(of:) or regex.wholeStringMatch(in:) for String and Substring inputs.")
    public func wholeMatch(in str: Substring, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchConfiguration: nil)
        }
    }

    /// Searches the full input and returns a region only when the regex covers the entire input.
    ///
    /// This overload also applies the supplied per-search match configuration.
    public func wholeMatch<S>(in str: S, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchConfiguration: matchConfiguration)
        }
    }

    @available(*, deprecated, message: "Use input.wholeMatch(of:matchConfiguration:) or regex.wholeStringMatch(in:matchConfiguration:) for String and Substring inputs.")
    public func wholeMatch(in str: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchConfiguration: matchConfiguration)
        }
    }

    @available(*, deprecated, message: "Use input.wholeMatch(of:matchConfiguration:) or regex.wholeStringMatch(in:matchConfiguration:) for String and Substring inputs.")
    public func wholeMatch(in str: Substring, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchConfiguration: matchConfiguration)
        }
    }

    internal func _wholeMatch<S>(in str: S, options: SearchOptions = .none, matchConfiguration: MatchConfiguration?) throws -> Region? where S: OnigurumaString {
        try str.withOnigurumaString(requestedEncoding: self.encoding) { (start, count) throws -> Region? in
            guard let region = try _firstMatchResolved(in: str,
                                                       start: start,
                                                       count: count,
                                                       range: 0..<count,
                                                       options: options.union(.matchWholeString),
                                                       matchConfiguration: matchConfiguration),
                  region.byteRange == 0..<count else {
                return nil
            }

            return region
        }
    }
    
    /// Returns the encoded byte length of the first match found within a byte range.
    ///
    /// This is a low-level convenience around `onig_match`/`onig_match_with_param` for callers
    /// that need only the matched byte count rather than a full `Region`.
    public func matchedByteCount<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Int? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: range, options: options, matchConfiguration: nil)
        }
    }

    private func _matchCount<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchConfiguration: MatchConfiguration?) throws -> Int? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try str.withOnigurumaString(requestedEncoding: self.encoding) { (start, count) throws -> Int? in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            let result = try callOnigFunction {
                if let matchConfiguration {
                    return try matchConfiguration.withRawValue { rawMatchParam in
                        onig_match_with_param(self.rawValue,
                                              start,
                                              start.advanced(by: count),
                                              start.advanced(by: range.lowerBound),
                                              nil,
                                              options.rawValue,
                                              rawMatchParam)
                    }
                }

                return onig_match(self.rawValue,
                                  start,
                                  start.advanced(by: count),
                                  start.advanced(by: range.lowerBound),
                                  nil,
                                  options.rawValue)
            }
            
            if result == ONIG_MISMATCH {
                return nil
            }
            
            return Int(result)
        }
    }
    
    /// Returns the encoded byte length of the first match found in the entire input.
    public func matchedByteCount<S>(in str: S, options: SearchOptions = .none) throws -> Int? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil)
        }
    }

    /// Returns the encoded byte length of the first match in a byte range using custom match configuration.
    public func matchedByteCount<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Int? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: range, options: options, matchConfiguration: matchConfiguration)
        }
    }

    /// Returns the encoded byte length of the first match in the entire input using custom match configuration.
    public func matchedByteCount<S>(in str: S, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Int? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration)
        }
    }

    private func _matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none, matchConfiguration: MatchConfiguration?) throws -> Bool where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        try _matchCount(in: str, of: range, options: options, matchConfiguration: matchConfiguration) != nil
    }
    
    /// Returns whether the regex matches anywhere within the provided byte range.
    ///
    /// This is a raw-byte predicate. Use `String.contains(_:)` for the string-native equivalent.
    public func matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none) throws -> Bool where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: range, options: options, matchConfiguration: nil)
        }
    }
    
    /// Returns whether the regex matches anywhere in the provided input.
    public func matches<S>(_ str: S, options: SearchOptions = .none) throws -> Bool {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: Self.fullByteRange, options: options, matchConfiguration: nil)
        }
    }

    /// Returns whether the regex matches within the provided byte range using custom match configuration.
    public func matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Bool where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: range, options: options, matchConfiguration: matchConfiguration)
        }
    }

    /// Returns whether the regex matches anywhere in the provided input using custom match configuration.
    public func matches<S>(_ str: S, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Bool {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration)
        }
    }

    @discardableResult public func enumerateMatches<S>(in str: S,
                                                       options: SearchOptions = .none,
                                                       matchConfiguration: MatchConfiguration = MatchConfiguration(),
                                                       body: @escaping @Sendable (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) throws -> Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _enumerateMatches(in: supported,
                                  of: Self.fullByteRange,
                                  options: options,
                                  matchConfiguration: matchConfiguration,
                                  body: body)
        }
    }

    private final class ScanContext: @unchecked Sendable {
        let region: Region
        let callback: @Sendable (Int, Int, Region) -> Bool
        init(region: Region, callback: @escaping @Sendable (Int, Int, Region) -> Bool) {
            self.region = region
            self.callback = callback
        }
    }

    /// Enumerates all non-overlapping raw matches within a byte range.
    ///
    /// The callback receives matches in forward search order. Returning `false` stops enumeration
    /// early and causes `onig_scan` to abort normally.
    ///
    /// - Parameters:
    ///   - str: The input to search.
    ///   - range: The encoded byte range to scan.
    ///   - options: Search-time options used during scanning.
    ///   - matchConfiguration: Per-search limits and callout handlers.
    ///   - body: Called once per match with the match order, matched byte index, and raw region.
    /// - Returns: The number of matches that were delivered before completion or abort.
    /// - Throws: `OnigError` if scanning fails.
    @discardableResult public func enumerateMatches<S, R>(in str: S,
                                                          of range: R,
                                                          options: SearchOptions = .none,
                                                          matchConfiguration: MatchConfiguration = MatchConfiguration(),
                                                          body: @escaping @Sendable (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) throws -> Int where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _enumerateMatches(in: supported, of: range, options: options, matchConfiguration: matchConfiguration, body: body)
        }
    }

    func _enumerateMatches<S, R>(in str: S,
                                 of range: R,
                                 options: SearchOptions = .none,
                                 matchConfiguration: MatchConfiguration = MatchConfiguration(),
                                 body: @escaping @Sendable (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) throws -> Int where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        let result = try str.withOnigurumaString(requestedEncoding: self.encoding) { (start, count) throws -> OnigInt in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            let region = try Region(regex: self, str: str)

            let context = ScanContext(region: region, callback: body)
            let contextPtr = Unmanaged.passUnretained(context).toOpaque()

            return try callOnigFunction {
                onig_scan(self.rawValue,
                          start.advanced(by: range.lowerBound),
                          start.advanced(by: range.upperBound),
                          region.rawValue,
                          options.rawValue,
                          { (order, matchedIndex, onigRegion, contextPtr) -> OnigInt in
                            guard let contextPtr = contextPtr else {
                                return ONIGERR_INVALID_ARGUMENT
                            }
                            let context = Unmanaged<ScanContext>.fromOpaque(contextPtr).takeUnretainedValue()

                            let region: Region
                            do {
                                region = try Region(copying: onigRegion, regex: context.region.regex, str: context.region.str)
                            } catch let error as OnigError {
                                return error.onigErrorCode
                            } catch {
                                return ONIGERR_MEMORY
                            }

                            if context.callback(Int(order), Int(matchedIndex), region) {
                                return ONIG_NORMAL
                            } else {
                                return ONIG_ABORT
                            }
                          }, contextPtr)
            }
        }

        return Int(result)
    }

    // MARK: Capture groups
    
    /// The number of numeric capture groups in the compiled pattern.
    public var captureGroupsCount: Int {
        Int(onig_number_of_captures(self.rawValue))
    }
    
    /// The number of named capture groups in the compiled pattern.
    public var namedCaptureGroupsCount: Int {
        Int(onig_number_of_names(self.rawValue))
    }
    
    /// The number of capture-history groups enabled in the compiled pattern.
    ///
    /// - Note: Capture history requires syntax support for the relevant operator.
    public var captureHistoryCount: Int {
        Int(onig_number_of_capture_histories(self.rawValue))
    }

    /// Whether unnamed capture groups are active under the regex's current syntax and options.
    public var nonameGroupCaptureIsActive: Bool {
        onig_noname_group_capture_is_active(self.rawValue) != 0
    }
    
    /// Enumerates each named capture group and its numeric capture slots.
    ///
    /// A single name may map to multiple numeric groups under Oniguruma semantics.
    public func enumerateCaptureGroupNames(_ body: @escaping @Sendable (_ name: String, _ numbers: [Int]) -> Bool) {
        let context = ForeachNameContext(encoding: self.encoding, callback: body)
        withExtendedLifetime(context) {
            let contextPtr = Unmanaged.passUnretained(context).toOpaque()
            onig_foreach_name(self.rawValue, onigForeachNameCallback, contextPtr)
        }
    }
    
    /// Returns the numeric capture group slots associated with a named capture.
    ///
    /// - Returns: An empty array when the name does not exist in the compiled pattern.
    public func captureGroupNumbers(for name: String) -> [Int] {
        storage.matchMetadata.namedCaptureGroupNumbers[name] ?? []
    }
}

// MARK: Regex options and search options

extension Regex {
    /// Regex parsing and compilation options.
    ///
    /// These options affect how the pattern is compiled, not how an already-compiled regex
    /// searches a particular input.
    public struct Options: OptionSet, Sendable {
        public let rawValue: OnigOptionType
        
        public init(rawValue: OnigOptionType) {
            self.rawValue = rawValue
        }
        
        /// None
        public static let none = Regex.Options(rawValue: ONIG_OPTION_NONE)
        
        /// Ignore case.
        public static let ignoreCase = Regex.Options(rawValue: ONIG_OPTION_IGNORECASE)

        /// Limit ignore-case matching to ASCII characters.
        public static let ignoreCaseIsASCII = Regex.Options(rawValue: ONIG_OPTION_IGNORECASE_IS_ASCII)
        
        /// Extended pattern form.
        public static let extend = Regex.Options(rawValue: ONIG_OPTION_EXTEND)
        
        /// `'.'` match with newline.
        public static let multiLine = Regex.Options(rawValue: ONIG_OPTION_MULTILINE);
        
        /// `'^'` -> `'\A'`, `'$'` -> `'\Z'`.
        public static let singleLine = Regex.Options(rawValue: ONIG_OPTION_SINGLELINE);
        
        /// Find longest match.
        public static let findLongest = Regex.Options(rawValue: ONIG_OPTION_FIND_LONGEST);
        
        /// Ignore empty match.
        public static let findNotEmpty = Regex.Options(rawValue: ONIG_OPTION_FIND_NOT_EMPTY);

        /// Limit word character classes and boundaries to ASCII.
        public static let wordIsASCII = Regex.Options(rawValue: ONIG_OPTION_WORD_IS_ASCII)

        /// Limit digit character classes to ASCII.
        public static let digitIsASCII = Regex.Options(rawValue: ONIG_OPTION_DIGIT_IS_ASCII)

        /// Limit whitespace character classes to ASCII.
        public static let spaceIsASCII = Regex.Options(rawValue: ONIG_OPTION_SPACE_IS_ASCII)

        /// Limit POSIX character classes to ASCII.
        public static let posixIsASCII = Regex.Options(rawValue: ONIG_OPTION_POSIX_IS_ASCII)

        /// Treat text segments as extended grapheme clusters.
        public static let textSegmentExtendedGraphemeCluster = Regex.Options(rawValue: ONIG_OPTION_TEXT_SEGMENT_EXTENDED_GRAPHEME_CLUSTER)

        /// Treat text segments as words.
        public static let textSegmentWord = Regex.Options(rawValue: ONIG_OPTION_TEXT_SEGMENT_WORD)
        
        /// Clear `OPTION_SINGLELINE` which is enabled on
        /// `SYNTAX_POSIX_BASIC`, `SYNTAX_POSIX_EXTENDED`,
        /// `SYNTAX_PERL`, `SYNTAX_PERL_NG`, `SYNTAX_JAVA`.
        public static let negateSingleLine = Regex.Options(rawValue: ONIG_OPTION_NEGATE_SINGLELINE);
        
        /// Only named group captured.
        public static let dontCaptureGroup = Regex.Options(rawValue: ONIG_OPTION_DONT_CAPTURE_GROUP);
        
        /// Named and no-named group captured.
        public static let captureGroup = Regex.Options(rawValue: ONIG_OPTION_CAPTURE_GROUP);
    }
    
    /// Regex evaluation options.
    ///
    /// These options affect a particular search or match operation.
    public struct SearchOptions: OptionSet, Sendable {
        public let rawValue: OnigOptionType
        
        public init(rawValue: OnigOptionType) {
            self.rawValue = rawValue
        }
        
        /// None.
        public static let none = SearchOptions(rawValue: ONIG_OPTION_NONE)
        
        /// Do not regard the beginning of the (str) as the beginning of the line and the beginning of the string
        public static let notBol = SearchOptions(rawValue: ONIG_OPTION_NOTBOL);
        
        /// Do not regard the (end) as the end of a line and the end of a string
        public static let notEol = SearchOptions(rawValue: ONIG_OPTION_NOTEOL);
        
        /// Do not regard the beginning of the (str) as the beginning of a string  (* fail \A)
        public static let notBeginString = SearchOptions(rawValue: ONIG_OPTION_NOT_BEGIN_STRING)
        
        /// Do not regard the (end) as a string endpoint  (* fail \z, \Z)
        public static let notEndString = SearchOptions(rawValue: ONIG_OPTION_NOT_END_STRING)
        
        /// Do not regard the (start) as start position of search  (* fail \G)
        public static let notBeginPosition = SearchOptions(rawValue: ONIG_OPTION_NOT_BEGIN_POSITION)

        /// Request callback delivery for each successful match.
        public static let callbackEachMatch = SearchOptions(rawValue: ONIG_OPTION_CALLBACK_EACH_MATCH)

        /// Require the whole input to match.
        public static let matchWholeString = SearchOptions(rawValue: ONIG_OPTION_MATCH_WHOLE_STRING)
    }
}
