//
//  Regex.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig
import OnigInternal
import Foundation

/**
 Regular Expression
 
 Use `Regex` to search against given pattern.
 
 Those APIs are in the TODO list:
 - `onig_get_case_fold_flag`
 - `onig_noname_group_capture_is_active`
 */
final public class Regex: Sendable {
    // MARK: Private members

    internal private(set) nonisolated(unsafe) var rawValue: OnigRegex!

    /**
     Pattern in raw bytes of the regular expression.
     */
    private nonisolated(unsafe) var _patternBytes: ContiguousArray<UInt8>!
    
    /**
     Syntax of the regular expression.
     
     Keep a reference to the syntax to make sure the address to the syntax used in oniguruma is always valid.
     */
    private nonisolated(unsafe) var _syntax: Syntax!
    
    /**
     Encoding of the regular expression.

     Keep a reference to the encoding to make sure the address to the encoding used in oniguruma is always valid.
     */
    private nonisolated(unsafe) var _encoding: Encoding!
    
    /**
     Option of the regular expression.
     */
    private let _options: Options
    
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
    public convenience init<S>(pattern: S,
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
        self._patternBytes = ContiguousArray(patternBytes)
        self._encoding = encoding
        self._options = options
        let defaultSyntax = await Syntax.default
        let actualSyntax = syntax ?? defaultSyntax
        self._syntax = actualSyntax

        var error = OnigErrorInfo()
        let result = self._patternBytes.withUnsafeBufferPointer { bufPtr -> OnigInt in
            // Make sure that `onig_new` isn't called by more than one thread at a time.
            onig_new(&self.rawValue,
                     bufPtr.baseAddress,
                     bufPtr.baseAddress?.advanced(by: self._patternBytes.count),
                     options.rawValue,
                     encoding.rawValue,
                     actualSyntax.rawValue,
                     &error)
        }
        
        if result != ONIG_NORMAL {
            self._cleanUp()
            throw OnigError(onigErrorCode: result, onigErrorInfo: error)
        }
    }
    
    deinit {
        self._cleanUp()
    }
    
    // MARK: Accessors
    
    /**
     The option used to create this regex.
     */
    public var options: Options {
        get {
            return Options(rawValue: onig_get_options(self.rawValue))
        }
    }
    
    /**
     The encoding used to create this regex.
     */
    public var encoding: Encoding {
        get {
            return Encoding(rawValue: onig_get_encoding(self.rawValue))
        }
    }
    
    /**
     The syntax used to create this regex.
     */
    public var syntax: Syntax {
        get {
            return Syntax(rawValue: onig_get_syntax(self.rawValue))
        }
    }
    
    // MARK: Match & Search
    
    /**
     Search the string and find the first matching region.
     
     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.
     - Parameters:
         - str: Target string to search against.
         - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
         - option: The regular expression search options.
     - Returns: The first matching region if there is any, otherwise `nil`.
     - Throws: `OnigError`
     */
    public func firstMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Region? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try str.withOnigurumaString { (start, count) throws -> Region? in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            let region = try Region(regex: self, str: str)
            let result = try callOnigFunction {
                onig_search(self.rawValue,
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
    public func firstMatch<S>(in str: S, options: SearchOptions = .none) throws -> Region? where S: OnigurumaString {
        return try self.firstMatch(in: str, of: 0..., options: options)
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
    public func matchCount<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Int? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try str.withOnigurumaString { (start, count) throws -> Int? in
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            let result = try callOnigFunction {
                onig_match(self.rawValue,
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
    public func matchCount<S>(in str: S, options: SearchOptions = .none) throws -> Int? where S: OnigurumaString {
        return try self.matchCount(in: str, of: 0..., options: options)
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
    public func isMatch<S, R>(in str: S, of range: R, options: SearchOptions = .none) throws -> Bool where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try self.matchCount(in: str, of: range, options: options) != nil
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
    public func isMatch<S>(in str: S, options: SearchOptions = .none) throws -> Bool where S: OnigurumaString {
        return try self.isMatch(in: str, of: 0..., options: options)
    }
    
    @discardableResult public func enumerateMatches<S>(in str: S,
                                                       options: SearchOptions = .none,
                                                       matchParam: MatchParam = MatchParam(),
                                                       body: @escaping (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) throws -> Int where S: OnigurumaString {
        try self.enumerateMatches(in: str,
                                  of: 0...,
                                  options: options,
                                  matchParam: matchParam,
                                  body: body)
    }

    private class ScanContext {
        let region: Region
        let callback: (Int, Int, Region) -> Bool
        init(region: Region, callback: @escaping (Int, Int, Region) -> Bool) {
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
                                                          body: @escaping (_ order: Int, _ matchedIndex: Int, _ region: Region) -> Bool
    ) throws -> Int where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        let result = try str.withOnigurumaString { (start, count) throws -> OnigInt in
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
                                fatalError("Fail to retrieve the context")
                            }
                            let context = Unmanaged<ScanContext>.fromOpaque(contextPtr).takeUnretainedValue()

                            guard let region = try? Region(copying: onigRegion, regex: context.region.regex, str: context.region.str) else {
                                fatalError("Fail to creating the region")
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
     Enumerate each named capture group name and calling the closure with each entry.
     - Parameters:
         - body: The closure to call on each entry.
         - name: the group name.
         - numbers: group numbers of the group name.
     */
    public func enumerateCaptureGroupNames(_ body: @escaping @Sendable (_ name: String, _ numbers: [Int]) -> Bool) {
        if self.rawValue == nil {
            return
        }
        
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
        return Array(name.utf8).withUnsafeBufferPointer { bufPtr -> [Int] in
            let start = bufPtr.baseAddress!
            let count = onig_name_to_group_numbers(self.rawValue,
                                                   start,
                                                   start.advanced(by: bufPtr.count),
                                                   nil)
            
            if count < 0 {
                return []
            }
            
            var nums: UnsafeMutablePointer<OnigInt>? = nil
            _ = onig_name_to_group_numbers(self.rawValue,
                                                   start,
                                                   start.advanced(by: bufPtr.count),
                                                   &nums)
      
            guard let numbersPtr = nums else {
                return []
            }
            
            return [Int](UnsafeBufferPointer.init(start: numbersPtr, count: Int(count)).map { Int($0) })
        }
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
    
    // MARK: Private methods
    
    /**
     Clean up oniguruma regex object and cacahed pattern bytes.
     */
    private func _cleanUp() {
        if self.rawValue != nil {
            onig_free(self.rawValue)
            self.rawValue = nil
        }
        self._patternBytes = nil
        self._encoding = nil
        self._syntax = nil
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
        
        /// Extended pattern form.
        public static let extend = Regex.Options(rawValue: get_onig_option_extend())
        
        /// `'.'` match with newline.
        public static let multiLine = Regex.Options(rawValue: get_onig_option_multiline());
        
        /// `'^'` -> `'\A'`, `'$'` -> `'\Z'`.
        public static let singleLine = Regex.Options(rawValue: get_onig_option_singleline());
        
        /// Find longest match.
        public static let findLongest = Regex.Options(rawValue: get_onig_option_find_longest());
        
        /// Ignore empty match.
        public static let findNotEmpty = Regex.Options(rawValue: get_onig_option_find_not_empty());
        
        /// Clear `OPTION_SINGLELINE` which is enabled on
        /// `SYNTAX_POSIX_BASIC`, `SYNTAX_POSIX_EXTENDED`,
        /// `SYNTAX_PERL`, `SYNTAX_PERL_NG`, `SYNTAX_JAVA`.
        public static let negateSingleLine = Regex.Options(rawValue: get_onig_option_negate_singleline());
        
        /// Only named group captured.
        public static let dontCaptureGroup = Regex.Options(rawValue: get_onig_option_dont_capture_group());
        
        /// Named and no-named group captured.
        public static let captureGroup = Regex.Options(rawValue: get_onig_option_capture_group());
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
        public static let notBol = SearchOptions(rawValue: get_onig_option_notbol());
        
        /// Do not regard the (end) as the end of a line and the end of a string
        public static let notEol = SearchOptions(rawValue: get_onig_option_noteol());
        
        /// Do not regard the beginning of the (str) as the beginning of a string  (* fail \A)
        public static let notBeginString = SearchOptions(rawValue: get_onig_option_not_begin_string())
        
        /// Do not regard the (end) as a string endpoint  (* fail \z, \Z)
        public static let notEndString = SearchOptions(rawValue: get_onig_option_not_end_string())
        
        /// Do not regard the (start) as start position of search  (* fail \G)
        public static let notBeginPosition = SearchOptions(rawValue: get_onig_option_not_begin_position())
    }
}
