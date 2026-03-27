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

/**
 Regular Expression
 
 Use `Regex` to search against given pattern.
 
 Those APIs are in the TODO list:
 - `onig_get_case_fold_flag`
 - `onig_noname_group_capture_is_active`
 */
public struct Regex: Sendable, CustomConsumingRegexComponent {
    public typealias RegexOutput = Substring
    private static let fullByteRange: PartialRangeFrom<Int> = 0...

    internal final class Storage: @unchecked Sendable {
        let rawValue: OnigRegex
        let patternBytes: ContiguousArray<UInt8>
        let rawSyntax: UnsafeMutablePointer<OnigSyntaxType>
        let syntax: Syntax
        let encoding: Encoding
        let options: Options

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

            self.rawValue = rawValue
            self.patternBytes = compiledPatternBytes
            self.rawSyntax = rawSyntax
            self.syntax = syntax
            self.encoding = encoding
            self.options = options
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
        
        guard let region = try self._firstMatch(in: input, of: startOffset..<endOffset, options: .none, matchParam: nil) else {
            return nil
        }
        
        let matchRange = region.range
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
    
    // MARK: init & deinit
    
    /**
     Create a `Regex` object with given string pattern, options and syntax.
     
     As swift string uses UTF-8 as internal storage from swift 5, UTF-8 encoding (`Encoding.utf8`) will be used for swift string pattern.
     - Parameters:
         - pattern: Pattern used to create the regular expression.
         - option: Options used to create the regular expression.
         - syntax: Syntax used to create the regular expression. If `nil`, `Syntax.default` will be used.
     - Throws: `OnigError`
     */
    @OnigurumaActor
    public init<S>(pattern: S,
                   options: Options = .none,
                   syntax: Syntax? = nil
    ) async throws where S: StringProtocol {
        try await self.init(patternBytes: pattern.utf8, encoding: Encoding.utf8, options: options, syntax: syntax)
    }

    /**
     Create a `Regex` with given pattern, encoding, options and syntax.
     - Parameters:
         - pattern: Pattern used to create the regular expression, represented with a sequence of bytes.
         - encoding: Encoding used to create the the regular expression.
         - option: Options used to create the regular expression.
         - syntax: Syntax used to create the regular expression. If `nil`, `Syntax.default` will be used.
     - Throws: `OnigError`
     */
    @OnigurumaActor
    public init<S>(patternBytes: S,
                   encoding: Encoding,
                   options: Options = .none,
                   syntax: Syntax? = nil
    ) async throws where S: Sequence, S.Element == UInt8 {
        try await OnigurumaActor.shared.ensureInitialized(encoding: encoding.rawValue)
        let actualSyntax = syntax ?? Syntax.default
        self.storage = try Storage(patternBytes: patternBytes,
                                   encoding: encoding,
                                   options: options,
                                   syntax: actualSyntax)
    }
    
    // MARK: Accessors
    
    /**
     The option used to create this regex.
     */
    public var options: Options {
        get {
            storage.options
        }
    }
    
    /**
     The encoding used to create this regex.
     */
    public var encoding: Encoding {
        get {
            storage.encoding
        }
    }
    
    /**
     The syntax used to create this regex.
     */
    public var syntax: Syntax {
        get async {
            storage.syntax
        }
    }
    
    // MARK: Match & Search
    
    /// Searches the string and returns the first matching region.
    ///
    /// If `str` conforms to `StringProtocol`, the search is performed against the UTF-8 bytes of the string.
    ///
    /// - Parameters:
    ///   - str: The target string to search against.
    ///   - range: The range of bytes to search against.
    ///   - options: The regular expression search options.
    /// - Returns: The first matching region if found, otherwise `nil`.
    /// - Throws: `OnigError` if the search fails.
    public func firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Region? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: range, options: options, matchParam: nil)
        }
    }

    private func _firstMatchResolved<S>(
        in str: S,
        start: UnsafePointer<OnigUChar>,
        count: Int,
        range: Range<Int>,
        options: SearchOptions,
        matchParam: MatchParam?
    ) throws -> Region? where S: OnigurumaString {
        let region = try Region(regex: self, str: str)
        let result = try callOnigFunction {
            if let matchParam {
                return try matchParam.withRawValue { rawMatchParam in
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

    private func _firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchParam: MatchParam?) throws -> Region? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try str.withOnigurumaString(requestedEncoding: self.encoding) { (start, count) throws -> Region? in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            return try _firstMatchResolved(in: str,
                                           start: start,
                                           count: count,
                                           range: range,
                                           options: options,
                                           matchParam: matchParam)
        }
    }
    
    /**
     Search the string and find the first matching region.
     
     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - option: The regular expression search options.
     - Returns: The first matching region if there is any, otherwise `nil`.
     - Throws: `OnigError`
     */
    public func firstMatch<S>(in str: S, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: nil)
        }
    }

    /**
     Search the string and find the first matching region using the supplied match parameters.
     */
    public func firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchParam: MatchParam) throws -> Region? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: range, options: options, matchParam: matchParam)
        }
    }

    /**
     Search the string and find the first matching region using the supplied match parameters.
     */
    public func firstMatch<S>(in str: S, options: SearchOptions = .none, matchParam: MatchParam) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam)
        }
    }

    /**
     Async version of `firstMatch`.
     */
    public func firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none) async throws -> Region? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: range, options: options, matchParam: nil)
        }
    }

    /**
     Async version of `firstMatch`.
     */
    public func firstMatch<S>(in str: S, options: SearchOptions = .none) async throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: nil)
        }
    }

    /**
     Async version of `firstMatch`.
     */
    public func firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchParam: MatchParam) async throws -> Region? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: range, options: options, matchParam: matchParam)
        }
    }

    /**
     Async version of `firstMatch`.
     */
    public func firstMatch<S>(in str: S, options: SearchOptions = .none, matchParam: MatchParam) async throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam)
        }
    }

    /**
     Search the full input and return a region only when the entire string matches.
     */
    public func wholeMatch<S>(in str: S, options: SearchOptions = .none) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchParam: nil)
        }
    }

    /**
     Search the full input and return a region only when the entire string matches.
     */
    public func wholeMatch<S>(in str: S, options: SearchOptions = .none, matchParam: MatchParam) throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchParam: matchParam)
        }
    }

    /**
     Async version of `wholeMatch`.
     */
    public func wholeMatch<S>(in str: S, options: SearchOptions = .none) async throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchParam: nil)
        }
    }

    /**
     Async version of `wholeMatch`.
     */
    public func wholeMatch<S>(in str: S, options: SearchOptions = .none, matchParam: MatchParam) async throws -> Region? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _wholeMatch(in: supported, options: options, matchParam: matchParam)
        }
    }

    private func _wholeMatch<S>(in str: S, options: SearchOptions = .none, matchParam: MatchParam?) throws -> Region? where S: OnigurumaString {
        try str.withOnigurumaString(requestedEncoding: self.encoding) { (start, count) throws -> Region? in
            guard let region = try _firstMatchResolved(in: str,
                                                       start: start,
                                                       count: count,
                                                       range: 0..<count,
                                                       options: options.union(.matchWholeString),
                                                       matchParam: matchParam),
                  region.range == 0..<count else {
                return nil
            }

            return region
        }
    }
    
    /**
     Search the string and find the matched byte count.
     
     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
         - option: The regular expression search options.
     - Returns: The matched byte count if there is a match, otherwise `nil`.
     - Throws: `OnigError`
     */
    public func matchCount<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Int? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: range, options: options, matchParam: nil)
        }
    }

    private func _matchCount<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchParam: MatchParam?) throws -> Int? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try str.withOnigurumaString(requestedEncoding: self.encoding) { (start, count) throws -> Int? in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            let result = try callOnigFunction {
                if let matchParam {
                    return try matchParam.withRawValue { rawMatchParam in
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
    
    /**
     Search the string and find the matched byte count.
     
     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - option: The regular expression search options.
     - Returns: The matched byte count if there is a match, otherwise `nil`.
     - Throws: `OnigError`
     */
    public func matchCount<S>(in str: S, options: SearchOptions = .none) throws -> Int? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: Self.fullByteRange, options: options, matchParam: nil)
        }
    }

    /**
     Search the string and find the matched byte count using the supplied match parameters.
     */
    public func matchCount<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchParam: MatchParam) throws -> Int? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: range, options: options, matchParam: matchParam)
        }
    }

    /**
     Search the string and find the matched byte count using the supplied match parameters.
     */
    public func matchCount<S>(in str: S, options: SearchOptions = .none, matchParam: MatchParam) throws -> Int? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam)
        }
    }

    /**
     Async version of `matchCount`.
     */
    public func matchCount<S, R>(in str: S, of range: R, options: SearchOptions = .none) async throws -> Int? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: range, options: options, matchParam: nil)
        }
    }

    /**
     Async version of `matchCount`.
     */
    public func matchCount<S>(in str: S, options: SearchOptions = .none) async throws -> Int? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: Self.fullByteRange, options: options, matchParam: nil)
        }
    }

    /**
     Async version of `matchCount`.
     */
    public func matchCount<S, R>(in str: S, of range: R, options: SearchOptions = .none, matchParam: MatchParam) async throws -> Int? where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: range, options: options, matchParam: matchParam)
        }
    }

    /**
     Async version of `matchCount`.
     */
    public func matchCount<S>(in str: S, options: SearchOptions = .none, matchParam: MatchParam) async throws -> Int? {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matchCount(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam)
        }
    }

    private func _matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none, matchParam: MatchParam?) throws -> Bool where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        try _matchCount(in: str, of: range, options: options, matchParam: matchParam) != nil
    }
    
    /**
     Is the string matched by the regular expression?
     
     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
         - option: The regular expression search options.
     - Returns: `true` if it's matched, otherwise `false`.
     - Throws: `OnigError`
     */
    public func matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none) throws -> Bool where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: range, options: options, matchParam: nil)
        }
    }
    
    /**
     Is the string matched by the regular expression?
     
     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - option: The regular expression search options.
     - Returns: `true` if it's matched, otherwise `false`.
     - Throws: `OnigError`
     */
    public func matches<S>(_ str: S, options: SearchOptions = .none) throws -> Bool {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: Self.fullByteRange, options: options, matchParam: nil)
        }
    }

    /**
     Is the string matched by the regular expression using the supplied match parameters?
     */
    public func matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none, matchParam: MatchParam) throws -> Bool where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: range, options: options, matchParam: matchParam)
        }
    }

    /**
     Is the string matched by the regular expression using the supplied match parameters?
     */
    public func matches<S>(_ str: S, options: SearchOptions = .none, matchParam: MatchParam) throws -> Bool {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: Self.fullByteRange, options: options, matchParam: matchParam)
        }
    }

    /**
     Async version of `matches`.
     */
    public func matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none) async throws -> Bool where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: range, options: options, matchParam: nil)
        }
    }

    /**
     Async version of `matches`.
     */
    public func matches<S>(_ str: S, options: SearchOptions = .none) async throws -> Bool {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: Self.fullByteRange, options: options, matchParam: nil)
        }
    }

    /**
     Async version of `matches`.
     */
    public func matches<S, R>(_ str: S, in range: R, options: SearchOptions = .none, matchParam: MatchParam) async throws -> Bool where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: range, options: options, matchParam: matchParam)
        }
    }

    /**
     Async version of `matches`.
     */
    public func matches<S>(_ str: S, options: SearchOptions = .none, matchParam: MatchParam) async throws -> Bool {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _matches(supported, in: Self.fullByteRange, options: options, matchParam: matchParam)
        }
    }

    @available(*, deprecated, renamed: "matches(_:in:options:)")
    public func isMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Bool where R: RangeExpression, R.Bound == Int {
        return try matches(str, in: range, options: options)
    }

    @available(*, deprecated, renamed: "matches(_:options:)")
    public func isMatch<S>(in str: S, options: SearchOptions = .none) throws -> Bool {
        return try matches(str, options: options)
    }

    @available(*, deprecated, renamed: "matches(_:in:options:)")
    public func isMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none) async throws -> Bool where R: RangeExpression, R.Bound == Int {
        return try await matches(str, in: range, options: options)
    }

    @available(*, deprecated, renamed: "matches(_:options:)")
    public func isMatch<S>(in str: S, options: SearchOptions = .none) async throws -> Bool {
        return try await matches(str, options: options)
    }
    
    @discardableResult public func enumerateMatches<S>(in str: S,
                                                       options: SearchOptions = .none,
                                                       matchParam: MatchParam = MatchParam(),
                                                       body: @escaping @Sendable (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) throws -> Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _enumerateMatches(in: supported,
                                  of: Self.fullByteRange,
                                  options: options,
                                  matchParam: matchParam,
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

    /**
     Scan the string and calling the closure with each matching region.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
         - body: The closure to call on each match.
         - order: The order of this match.
         - matchedIndex: The matched index of byte.
         - region: The matching region.
     - Returns: Number of matches. If only the number of matches is needed, `numberOfMatches(in:of:options:matchParams:body:)` is slightly faster.
     - Throws: `OnigError`
     */
    @discardableResult public func enumerateMatches<S, R>(in str: S,
                                                          of range: R,
                                                          options: SearchOptions = .none,
                                                          matchParam: MatchParam = MatchParam(),
                                                          body: @escaping @Sendable (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) throws -> Int where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _enumerateMatches(in: supported, of: range, options: options, matchParam: matchParam, body: body)
        }
    }

    private func _enumerateMatches<S, R>(in str: S,
                                         of range: R,
                                         options: SearchOptions = .none,
                                         matchParam: MatchParam = MatchParam(),
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

    /**
     Async version of `enumerateMatches`.
     */
    @discardableResult public func enumerateMatches<S, R>(in str: S,
                                                          of range: R,
                                                          options: SearchOptions = .none,
                                                          matchParam: MatchParam = MatchParam(),
                                                          body: @escaping @Sendable (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) async throws -> Int where R: RangeExpression, R.Bound == Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _enumerateMatches(in: supported, of: range, options: options, matchParam: matchParam, body: body)
        }
    }

    /**
     Async version of `enumerateMatches`.
     */
    @discardableResult public func enumerateMatches<S>(in str: S,
                                                       options: SearchOptions = .none,
                                                       matchParam: MatchParam = MatchParam(),
                                                       body: @escaping @Sendable (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) async throws -> Int {
        try withSupportedOnigurumaInput(str, requestedEncoding: self.encoding) { supported in
            try _enumerateMatches(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam, body: body)
        }
    }

    // MARK: Capture groups
    
    /**
     Get the count of capture groups of the pattern.
     */
    public var captureGroupsCount: Int {
        Int(onig_number_of_captures(self.rawValue))
    }
    
    /**
     Get the count of named capture groups of the pattern.
     */
    public var namedCaptureGroupsCount: Int {
        Int(onig_number_of_names(self.rawValue))
    }
    
    /**
     Get the count of capture history entries of the pattern.
     - Note: You can't use capture history if `.atmarkCaptureHistory` is disabled in the regex syntax.
     */
    public var captureHistoryCount: Int {
        Int(onig_number_of_capture_histories(self.rawValue))
    }

    /**
     Whether unnamed capture groups are active for this regex under its current options and syntax.
     */
    public var nonameGroupCaptureIsActive: Bool {
        onig_noname_group_capture_is_active(self.rawValue) != 0
    }
    
    /**
     Enumerate each named capture group name and calling the closure with each entry.
     - Parameters:
         - body: The closure to call on each entry.
         - name: the group name.
         - numbers: group numbers of the group name.
     */
    public func enumerateCaptureGroupNames(_ body: @escaping @Sendable (_ name: String, _ numbers: [Int]) -> Bool) {
        let context = ForeachNameContext(encoding: self.encoding, callback: body)
        withExtendedLifetime(context) {
            let contextPtr = Unmanaged.passUnretained(context).toOpaque()
            onig_foreach_name(self.rawValue, onigForeachNameCallback, contextPtr)
        }
    }
    
    /**
     Get the numbers of named capture groups with a specified name.
     - Parameter name: The name of named capture groups.
     - Returns: A array of group numbers. Empty if no named group matches.
     */
    public func captureGroupNumbers(for name: String) -> [Int] {
        final class CaptureGroupNumbersBox: @unchecked Sendable {
            var numbers = [Int]()
        }

        let box = CaptureGroupNumbersBox()
        self.enumerateCaptureGroupNames { groupName, numbers in
            guard groupName == name else {
                return true
            }

            box.numbers = numbers
            return false
        }

        return box.numbers
    }
    
    // MARK: Static properties
    
    /**
     Get the limit of subexp call count.
     - Note: Defaul value is `0` which means unlimited.
     */
    @OnigurumaActor
    public static var subexpCallLimitInSearch: UInt {
        get {
            UInt(onig_get_subexp_call_limit_in_search())
        }
        
        set {
            _ = onig_set_subexp_call_limit_in_search(OnigULong(newValue))
        }
    }
    
    /**
     Get or set the limit level of subexp call nest level.
     - Note: Default value is `24`.
     */
    @OnigurumaActor
    public static var subexpCallMaxNestLevel: Int {
        get {
            Int(onig_get_subexp_call_max_nest_level())
        }
        
        set {
            _ = onig_set_subexp_call_max_nest_level(OnigInt(newValue))
        }
    }
    
    /**
     Get or set the maximum depth of parser recursion.
     - Note: Default value is `4096`, if the `newValue` is `0`, default value which is `4096` will be set,
     */
    @OnigurumaActor
    public static var parseDepthLimit: UInt {
        get {
            UInt(onig_get_parse_depth_limit())
        }
        
        set {
            _ = onig_set_parse_depth_limit(OnigUInt(newValue))
        }
    }
    
}

// MARK: Regex options and search options

extension Regex {
    /// Regex parsing and compilation options.
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
