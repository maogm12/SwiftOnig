//
//  Regex.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig
import Foundation

/**
 A wrapper of oniguruma `OnigRegex` which represents the a regular expression.
 
 In `SwiftOnig`, `Regex` is supposed to be immutable, thoses APIs in oniguruma are wrapped:
 - `onig_new`: wrapped in `init`.
 - `onig_free`: wrapped in `deinit`.
 - `onig_match`, `onig_match_with_param`: wrapped with `isMatch(*)`, `matchedByteCount(*)` and `match(*)`.
 - `onig_search`, `onig_search_with_param`: wrapped with `firstIndex(*)` and `firstMatch(*)`.
 - `onig_scan`: wrapped with `matches(*)` and `enumerateMatches(*)`.
 - `onig_name_to_group_numbers`: wrapped with `namedCaptureGroupIndexes(of:)`.
 - `onig_foreach_name`: wrapped with `enumerateNamedCaptureGroups(:)`
 - `onig_number_of_names`: wrapped with `namedCaptureGroupCount`.
 - `onig_number_of_captures`: wrapped with `onig_number_of_captures`.
 - `onig_number_of_capture_histories`: wrapped with `captureHistoryCount`.

 Those APIs are not wrapped.
 - `onig_new_without_alloc`, because it might leave the regex in an invalid state once it throws, also `Regex` is supposed to be immutable.
 - `onig_reg_init`, as it's already called in `onig_new*`.
 - `onig_new_deluxe`, deprecated.
 - `onig_free_body`, no need to keep `OnigRegex` object for reusing.
 - `onig_get_encoding`, `onig_get_syntax`, `onig_get_options`: implemented with cached value in `Regex`.
 
 Those APIs are in the TODO list:
 - `onig_name_to_backref_number`
 - `onig_get_case_fold_flag`
 - `onig_noname_group_capture_is_active`
 */
final public class Regex {
    // MARK: Private members

    internal private(set) var rawValue: OnigRegex!

    /**
     Pattern in raw bytes of the regular expression.
     */
    private var _patternBytes: ContiguousArray<UInt8>!
    
    /**
     Syntax of the regular expression.
     
     Keep a reference to the syntax to make sure the address to the syntax used in oniguruma is always valid.
     */
    private var _syntax: Syntax!
    
    /**
     Encoding of the regular expression.

     Keep a reference to the encoding to make sure the address to the encoding used in oniguruma is always valid.
     */
    private var _encoding: Encoding!
    
    /**
     Option of the regular expression.
     */
    private var _options: Options
    
    // MARK: init & deinit
    
    /**
     Create a `Regex` object with given string pattern, options and syntax.
     
     As swift string uses UTF-8 as internal storage from swift 5, UTF-8 encoding (`Encoding.utf8`) will be used for swift string pattern.
     - Parameters:
         - pattern: Pattern used to create the regular expression.
         - option: Options used to create the regular expression.
         - syntax: Syntax used to create the regular expression.
     - Throws: `OnigError`
     */
    public convenience init<S>(pattern: S,
                               options: Options = .none,
                               syntax: Syntax = .default
    ) throws where S: StringProtocol {
        try self.init(patternBytes: pattern.utf8, encoding: Encoding.utf8, options: options, syntax: syntax)
    }

    /**
     Create a `Regex` with given pattern, encoding, options and syntax.
     - Parameters:
         - pattern: Pattern used to create the regular expression, represented with a sequence of bytes.
         - encoding: Encoding of the pattern.
         - option: Options used to create the regular expression.
         - syntax: Syntax used to create the regular expression.
     - Throws: `OnigError`
     */
    public init<S>(patternBytes: S,
                   encoding: Encoding,
                   options: Options = .none,
                   syntax: Syntax = .default
    ) throws where S: Sequence, S.Element == UInt8 {
        self._patternBytes = ContiguousArray(patternBytes)
        self._encoding = encoding
        self._options = options
        self._syntax = syntax

        var error = OnigErrorInfo()
        let result = self._patternBytes.withUnsafeBufferPointer { bufPtr -> OnigInt in
            // Make sure that `onig_new` isn't called by more than one thread at a time.
            onigQueue.sync {
                onig_new(&self.rawValue,
                         bufPtr.baseAddress,
                         bufPtr.baseAddress?.advanced(by: self._patternBytes.count),
                         options.rawValue,
                         encoding.rawValue,
                         self.syntax.rawValue,
                         &error)
            }
        }
        
        if result != ONIG_NORMAL {
            self._cleanUp()
            throw OnigError(onigErrorCode: result, onigErrorInfo: error)
        }
    }
    
    deinit {
        self._cleanUp()
    }
    
    // MARK: Properties
    
    /**
     Get the pattern string of the regular expression If the encoding is supported by swift string, otherwise `nil` is returned.
     */
    public var pattern: String? {
        guard let encoding = self._encoding?.stringEncoding else {
            return nil
        }
        
        return self._patternBytes.withUnsafeBufferPointer { patternBufPtr in
            String(bytes: patternBufPtr, encoding: encoding) ?? ""
        }
    }
    
    /**
     Get the pattern of the regular expression as in raw bytes.
     */
    public var patternBytes: ContiguousBytes {
        self._patternBytes
    }
    
    /**
     Get the sytnax of the regular expression.
     */
    public var syntax: Syntax {
        self._syntax
    }
    
    /**
     Get the encoding of the regular expression.
     */
    public var encoding: Encoding {
        self._encoding
    }
    
    /**
     Get the options of the regular expression.
     */
    public var options: Options {
        self._options
    }

    // MARK: match APIs
    
    /**
     Match string and returns true if and only if the regular expression matches the whole string given.
     
     If `str` conforms to `StringProtocol`, will match against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
        - str: Target string to match against
     - Returns:
     `true` if and only if the regex matches the whole string given, otherwise `false`.
     */
    public func isMatch<S>(_ str: S) -> Bool where S: OnigurumaString {
        guard let matchedCount = try? self.matchedByteCount(in: str) else {
            return false
        }

        return str.withOnigurumaString { (_, count) -> Bool in
            matchedCount == count
        }
    }

    /**
     Match string at specific position and return matched byte count.

     If `str` conforms to `StringProtocol`, will match against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to match against.
         - offset: The offset position of byte to start the match.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: Matched byte count from the offset if the regular expression matches, `nil` if it doesn't match.
     - Throws: `OnigError`
     */
    public func matchedByteCount<S>(in str: S,
                                    at offset: Int = 0,
                                    options: SearchOptions = .none,
                                    matchParam: MatchParam = MatchParam()
    ) throws -> Int? where S: OnigurumaString {
        let result = try str.withOnigurumaString { (start, count) in
            try callOnigFunction {
                onig_match_with_param(self.rawValue,
                                      start,
                                      start.advanced(by: count),
                                      start.advanced(by: offset),
                                      nil,
                                      options.rawValue,
                                      matchParam.rawValue)
            }
        }

        return result == ONIG_MISMATCH ? nil : Int(result)
    }

    /**
     Match string at specific position and return matching region.

     If `str` conforms to `StringProtocol`, will match against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to match against.
         - offset: The offset position of byte to start the match.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching region, or `nil` if it doesn't match.
     - Throws: `OnigError`
     */
    public func match<S>(in str: S,
                         at offset: Int = 0,
                         options: SearchOptions = .none,
                         matchParam: MatchParam = MatchParam()
    ) throws -> Region? where S: OnigurumaString {
        let region = try Region(with: self)
        let result = try str.withOnigurumaString { (start, count) in
            try callOnigFunction {
                precondition(offset >= 0 && offset < count, "Offset \(offset) is out of string bytes range \(0..<count)")
                return onig_match_with_param(self.rawValue,
                                             start,
                                             start.advanced(by: count),
                                             start.advanced(by: offset),
                                             region.rawValue,
                                             options.rawValue,
                                             matchParam.rawValue)
            }
        }
        
        return result == ONIG_MISMATCH ? nil : region
    }
    
    // MARK: Search APIs
    
    /**
     Search a string and return the first matching index of byte.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching index of byte, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstIndex<S>(in str: S,
                              options: SearchOptions = .none,
                              matchParam: MatchParam = MatchParam()
    ) throws -> Int? where S: OnigurumaString {
        try self.firstIndex(in: str,
                            of: 0...,
                            options: options,
                            matchParam: matchParam)
    }

    /**
     Search in a range of a string and return the first matching index of byte.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: Unbounded range represents the whole string.
         - option: The regex search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching index, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstIndex<S>(in str: S,
                              of range: UnboundedRange,
                              options: SearchOptions = .none,
                              matchParam: MatchParam = MatchParam()
    ) throws -> Int? where S: OnigurumaString {
        try self.firstIndex(in: str,
                            of: 0...,
                            options: options,
                            matchParam: matchParam)
    }

    /**
     Search in a range of a string and return the first matching index of byte.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
         - option: The regex search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching index, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstIndex<S, R>(in str: S,
                                 of range: R,
                                 options: SearchOptions = .none,
                                 matchParam: MatchParam = MatchParam()
    ) throws -> Int? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        let result = try str.withOnigurumaString { (start, count) throws -> OnigInt in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            return try callOnigFunction {
                onig_search_with_param(self.rawValue,
                                       start,
                                       start.advanced(by: count),
                                       start.advanced(by: range.lowerBound),
                                       start.advanced(by: range.upperBound),
                                       nil,
                                       options.rawValue,
                                       matchParam.rawValue)
            }
        }
        
        return Int(result)
    }
    
    /**
     Search a string and return the first matching region.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching region, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstMatch<S>(in str: S,
                              options: SearchOptions = .none,
                              matchParam: MatchParam = MatchParam()
    ) throws -> Region? where S: OnigurumaString {
        try self.firstMatch(in: str,
                            of: 0...,
                            options: options,
                            matchParam: matchParam)
    }
    
    /**
     Search a string and return the first matching region.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: Unbounded range represents the whole string.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching region, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstMatch<S>(in str: S,
                              of range: UnboundedRange,
                              options: SearchOptions = .none,
                              matchParam: MatchParam = MatchParam()
    ) throws -> Region? where S: OnigurumaString {
        try self.firstMatch(in: str,
                            of: 0...,
                            options: options,
                            matchParam: matchParam)
    }

    /**
     Search in a range of a string and return the first matching region.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching region, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstMatch<S, R>(in str: S,
                                 of range: R,
                                 options: SearchOptions = .none,
                                 matchParam: MatchParam = MatchParam()
    ) throws -> Region? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        let region = try Region(with: self)
        let result = try str.withOnigurumaString { (start, count) throws -> OnigInt in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            return try callOnigFunction {
                onig_search_with_param(self.rawValue,
                                       start,
                                       start.advanced(by: count),
                                       start.advanced(by: range.lowerBound),
                                       start.advanced(by: range.upperBound),
                                       region.rawValue,
                                       options.rawValue,
                                       matchParam.rawValue)
            }
        }
        
        if result == ONIG_MISMATCH {
            return nil
        } else {
            return region
        }
    }
    
    // MARK: Scan APIs
    
    /**
     Find all matching region in the string.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: An array of all matching regions, empty array if no match is found.
     - Throws: `OnigError`
     */
    public func matches<S>(in str: S,
                           options: SearchOptions = .none,
                           matchParam: MatchParam = MatchParam()
    ) throws -> [Region] where S: OnigurumaString {
        try self.matches(in: str,
                         of: 0...,
                         options: options,
                         matchParam: matchParam)
    }
    
    /**
     Find all matching region in the string.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: Unbounded range represents the whole string.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: An array of all matching regions, empty array if no match is found.
     - Throws: `OnigError`
     */
    public func matches<S>(in str: S,
                           of range: UnboundedRange,
                           options: SearchOptions = .none,
                           matchParam: MatchParam = MatchParam()
    ) throws -> [Region] where S: OnigurumaString {
        try self.matches(in: str,
                         of: 0...,
                         options: options,
                         matchParam: matchParam)
    }

    /**
     Find all matching region in the string.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
         - option: The regex search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: An array of all matched regions.
     - Throws: `OnigError`
     */
    public func matches<S, R>(in str: S,
                              of range: R,
                              options: SearchOptions = .none,
                              matchParam: MatchParam = MatchParam()
    ) throws -> [Region] where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        var regions = [Region]()
        try self.enumerateMatches(in: str,
                                  of: range,
                                  options: options,
                                  matchParam: matchParam) { regions.append($1); return true }
        return regions
    }
    
    /**
     Scan the string and calling the closure with each matching region.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
         - body: The closure to call on each match.
         - index: The matched index of byte.
         - region: The matching region.
     - Returns: Number of matches.
     - Throws: `OnigError`
     */
    @discardableResult public func enumerateMatches<S>(in str: S,
                                                       options: SearchOptions = .none,
                                                       matchParam: MatchParam = MatchParam(),
                                                       body: (_ index: Int,  _ region: Region) -> Bool
    ) throws -> Int where S: OnigurumaString {
        try self.enumerateMatches(in: str,
                                  of: 0...,
                                  options: options,
                                  matchParam: matchParam,
                                  body: body)
    }

    /**
     Scan the string and calling the closure with each matching region.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: Unbounded range represents the whole string.
         - option: The regular expression search options.
         - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
         - body: The closure to call on each match.
         - index: The matched index of byte.
         - region: The matching region.
     - Returns: Number of matches.
     - Throws: `OnigError`
     */
    @discardableResult public func enumerateMatches<S>(in str: S,
                                                       of range: UnboundedRange,
                                                       options: SearchOptions = .none,
                                                       matchParam: MatchParam = MatchParam(),
                                                       body: (_ index: Int,  _ region: Region) -> Bool
    ) throws -> Int where S: OnigurumaString {
        try self.enumerateMatches(in: str,
                                  of: 0...,
                                  options: options,
                                  matchParam: matchParam,
                                  body: body)
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
         - index: The matched index of byte.
         - region: The matching region.
     - Returns: Number of matches.
     - Throws: `OnigError`
     */
    @discardableResult public func enumerateMatches<S, R>(in str: S,
                                                          of range: R,
                                                          options: SearchOptions = .none,
                                                          matchParam: MatchParam = MatchParam(),
                                                          body: (_ index: Int, _ region: Region) -> Bool
    ) throws -> Int where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        typealias ContextType = (regex: Regex, callback: (Int, Region) -> Bool)

        let result = try str.withOnigurumaString { (start, count) throws -> OnigInt in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            let region = try Region(with: self)
            var context = (regex: self, callback: body)

            return try callOnigFunction {
                onig_scan(self.rawValue,
                          start.advanced(by: range.lowerBound),
                          start.advanced(by: range.upperBound),
                          region.rawValue,
                          options.rawValue,
                          { (_, index, onigRegion, contextPtr) -> Int32 in
                            guard let context = contextPtr?.assumingMemoryBound(to: ContextType.self).pointee else {
                                fatalError("Fail to retrive the context")
                            }

                            guard let region = try? Region(copying: onigRegion, regex: context.regex) else {
                                fatalError("Fail to creating the region")
                            }

                            if context.callback(Int(index), region) {
                                return ONIG_NORMAL
                            } else {
                                return ONIG_ABORT
                            }
                          }, &context)
            }
        }

        return Int(result)
    }

    // MARK: Capture groups
    
    /**
     Get the count of capture groups of the pattern.
     */
    public var captureGroupCount: Int {
        Int(onig_number_of_captures(self.rawValue))
    }
    
    /**
     Get the count of capture hisotries of the pattern.
     - Note: You can't use capture history if `.atmarkCaptureHistory` is disabled in the regex syntax.
     */
    public var captureHistoryCount: Int {
        Int(onig_number_of_capture_histories(self.rawValue))
    }
    
    // MARK: Oniguruma config

    /**
     Get or set the limit of subexp call count.
     - Note: Defaul value is `0` which means unlimited.
     */
    public static var subexpCallLimitInSearch: UInt {
        get {
            onigQueue.sync {
                UInt(onig_get_subexp_call_limit_in_search())
            }
        }
        
        set {
            onigQueue.sync {
                _ = onig_set_subexp_call_limit_in_search(OnigULong(newValue))
            }
        }
    }
    
    /**
     Get or set the limit level of subexp call nest level.
     - Note: Default value is `24`.
     */
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
    public static var parseDepthLimit: UInt {
        get {
            UInt(onig_get_parse_depth_limit())
        }
        
        set {
            _ = onig_set_parse_depth_limit(OnigUInt(newValue))
        }
    }
    
    // MARK: Private methods
    
    /**
     Clean up oniguruma regex object and cacahed pattern bytes.
     */
    private func _cleanUp() {
        if self.rawValue != nil {
            onig_free(self.rawValue)
            self.rawValue = nil
        }
        
        if self._patternBytes != nil {
            self._patternBytes = nil
        }
        
        if self._syntax != nil {
            self._syntax = nil
        }
        
        if self._encoding != nil {
            self._encoding = nil
        }
    }
}

// MARK: Regex options and search options

extension Regex {
    /// Regex parsing and compilation options.
    public struct Options: OptionSet {
        public let rawValue: OnigOptionType
        
        public init(rawValue: OnigOptionType) {
            self.rawValue = rawValue
        }
        
        /// Default options.
        public static let none = Regex.Options(rawValue: ONIG_OPTION_NONE)
        
        /// Ambiguity match on.
        public static let ignoreCase = Regex.Options(rawValue: ONIG_OPTION_IGNORECASE)
        
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
    public struct SearchOptions: OptionSet {
        public let rawValue: OnigOptionType
        
        public init(rawValue: OnigOptionType) {
            self.rawValue = rawValue
        }
        
        /// Default options.
        public static let none = SearchOptions(rawValue: ONIG_OPTION_NONE);
        
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
    }
}

// MARK: Named capture groups

extension Regex {
    /**
     Get the count of named groups of the pattern.
     */
    public var namedCaptureGroupCount: Int {
        Int(onig_number_of_names(self.rawValue))
    }
    
    /**
     Call `body` for each named capture group in the regular expression. Each callback gets the capture group name and capture group indexes.
     - TODO:
     Add iterator for named capture groups
     */
    public func enumerateNamedCaptureGroups(_ body: @escaping (_ name: String, _ indexes: [Int]) -> Bool) {
        if self.rawValue == nil {
            return
        }
        
        typealias NameCallbackType = (String, [Int]) -> Bool
        var closureRef = body
        
        onig_foreach_name(self.rawValue, { (namePtr, nameEndPtr, groupCount, groupsPtr, _ /* regex */, closureRefPtr) -> OnigInt in
            guard let name = String(utf8String: namePtr, end: nameEndPtr) else {
                return ONIG_ABORT
            }
            
            guard let groupsPtr = groupsPtr else {
                return ONIG_ABORT
            }
            
            var groupIndice = [Int]()
            for i in 0..<Int(groupCount) {
                groupIndice.append(Int(groupsPtr[i]))
            }
            
            guard let closure = closureRefPtr?.assumingMemoryBound(to: NameCallbackType.self).pointee else {
                fatalError("Failed to get the callback")
            }
            
            if closure(name, groupIndice) {
                return ONIG_NORMAL
            } else {
                return ONIG_ABORT
            }
        }, &closureRef)
    }
    
    /**
     Get the indexes of the named capture group with name.
     - Parameter name: The name of the named capture group.
     - Returns: An array of indexes of the named capture group, or `[]` if no such name is found.
     */
    public func namedCaptureGroupIndexes(of name: String) -> [Int] {
        name.withOnigurumaString { start, count in
            let nums = UnsafeMutablePointer<UnsafeMutablePointer<OnigInt>?>.allocate(capacity: 1)
            defer{
                nums.deallocate()
            }
            
            let count = onig_name_to_group_numbers(self.rawValue,
                                                   start,
                                                   start.advanced(by: count),
                                                   nums)
            
            if count < 0 {
                return []
            }
            
            guard let indexesPtr = nums.pointee else {
                return []
            }
            
            var indexes = [Int]()
            for i in 0..<Int(count) {
                indexes.append(Int(indexesPtr[i]))
            }
            
            return indexes
        }
    }
}
