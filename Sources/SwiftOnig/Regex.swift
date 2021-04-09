//
//  Regex.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig
import Foundation

final public class Regex {
    internal private(set) var rawValue: OnigRegex!

    /**
     Cached regex pattern bytes.
    */
    private var patternBytes: ContiguousArray<UInt8>!
    
    /**
     Keep a reference to the syntax to make sure the address to the syntax used in oniguruma is always valid.
     */
    private var syntax: Syntax!
    
    /**
     Keep a reference to the encoding to make sure the address to the encoding used in oniguruma is always valid.
     */
    private var encoding: Encoding!

    /**
     Create a `Regex` with given string pattern, option and syntax. UTF-8 encoding will be used for string pattern.
     - Parameters:
        - pattern: Pattern used to create the regex.
        - option: `Options` used to create the regex.
        - syntax: `Syntax` used to create the regex.
     - Throws:
        `OnigError`
     */
    public convenience init<S: StringProtocol>(_ pattern: S, option: Options = .none, syntax: Syntax = .default) throws {
        try self.init(pattern: pattern.utf8, encoding: Encoding.utf8, option: option, syntax: syntax)
    }

    /**
     Create a `Regex` with given bytes pattern, option and syntax.
     - Parameters:
        - pattern: Pattern of a sequence of bytes used to create the regex.
        - encoding: Encoding of the pattern.
        - option: `Options` used to create the regex.
        - syntax: `Syntax` used to create the regex.
     - Throws:
        `OnigError`
     */
    public init<S: Sequence>(pattern bytes: S, encoding: Encoding, option: Options = .none, syntax: Syntax = .default) throws where S.Element == UInt8 {
        self.patternBytes = ContiguousArray(bytes)
        self.syntax = syntax
        self.encoding = encoding

        var error = OnigErrorInfo()
        let result = self.patternBytes.withUnsafeBufferPointer { bufPtr -> OnigInt in
            // Make sure that `onig_new` isn't called by more than one thread at a time.
            onigQueue.sync {
                onig_new(&self.rawValue,
                         bufPtr.baseAddress,
                         bufPtr.baseAddress?.advanced(by: self.patternBytes.count),
                         option.rawValue,
                         encoding.rawValue,
                         self.syntax.rawValue,
                         &error)
            }
        }

        if result != ONIG_NORMAL {
            self.cleanUp()
            throw OnigError(result, onigErrorInfo: error)
        }
    }

    deinit {
        self.cleanUp()
    }
    
    /**
     Get the pattern string of the regular expression If the encoding is supported by swift string, otherwise `nil` is returned.
     */
    public var pattern: String? {
        guard let encoding = self.encoding?.stringEncoding else {
            return nil
        }
        
        return self.patternBytes.withUnsafeBufferPointer { patternBufPtr in
            String(bytes: patternBufPtr, encoding: encoding) ?? ""
        }
    }

    /**
     Match string and returns true if and only if the regex matches the whole string given.
     - Parameters:
        - str: Target string to match against
     - Returns:
        `true` if and only if the regex matches the whole string given, otherwise `false`.
     */
    public func isMatch<T: StringProtocol>(_ str: T) -> Bool {
        self.matchedByteCount(in: str) == str.utf8.count
    }

    /**
     Match string and return matched UTF-8 byte count. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to match against
     - Returns:
        Matched UTF-8 byte count from the beginning of the string if the regex matches, `nil` if it doesn't match.
     */
    public func matchedByteCount<T: StringProtocol>(in str: T, at utf8Offset: Int = 0) -> Int? {
        try? self.match(in: str, at: utf8Offset)?.matchedByteCount
    }

    /**
     Match string and return matched UTF-8 byte count.
     - Note:
        Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to match against
        - utf8Offset: The position to match against
        - option: The regex match options.
        - matchParam: Match parameter values (match_stack_limit, retry_limit_in_match, retry_limit_in_search)
     - Returns:
        A tuple of matched UTF-8 byte count and matching region, `nil` if it doesn't match.
     - Throws: `OnigError`
     */
    public func match<T: StringProtocol>(in str: T, at utf8Offset: Int = 0, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> (matchedByteCount: Int, region: Region)? {
        let byteCount = str.utf8.count
        if utf8Offset < 0 || utf8Offset >= byteCount {
            return nil
        }

        let region = try Region(with: self)
        let result = str.withCString { (cstr: UnsafePointer<Int8>) -> OnigInt in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> OnigInt in
                onig_match_with_param(self.rawValue,
                                      start,
                                      start.advanced(by: byteCount),
                                      start.advanced(by: utf8Offset),
                                      region.rawValue,
                                      options.rawValue,
                                      matchParam.rawValue)
            }
        }
        
        if result >= 0 {
            return (matchedByteCount: Int(result), region: region)
        } else if result == ONIG_MISMATCH {
            return nil
        }

        throw OnigError(result)
    }

    /**
     Search a string and return the first matching  index of UTF-8 bytes.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching index, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstIndex<T: StringProtocol>(in str: T, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> Int? {
        try self.firstIndex(in: str,
                            of: 0...,
                            options: options,
                            matchParam: matchParam)
    }

    /**
     Search in a range of a string and return the first matching index of UTF-8 bytes.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching index, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstIndex<T: StringProtocol, R: RangeExpression>(in str: T, of utf8Range: R, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> Int? where R.Bound == Int {
        try self.firstIndex(in: str,
                            of: utf8Range.relative(to: 0..<str.utf8.count),
                            options: options,
                            matchParam: matchParam)
    }
    
    /**
     Search in a range of a string and return the first matching index of UTF-8 bytes.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching index, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstIndex<T: StringProtocol>(in str: T, of utf8Range: Range<Int>, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> Int? {
        let result = try str.withOnigurumaString { (start, count) throws -> OnigInt in
            let range = utf8Range.clamped(to: 0..<count)
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
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching region, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstMatch<T: StringProtocol>(in str: T, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> Region? {
        try self.firstMatch(in: str,
                            of: 0...,
                            options: options,
                            matchParam: matchParam)
    }

    /**
     Search in a range of a string and return the first matching region.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching region, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstMatch<T: StringProtocol, R: RangeExpression>(in str: T, of utf8Range: R, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> Region? where R.Bound == Int {
        try self.firstMatch(in: str,
                            of: utf8Range.relative(to: 0..<str.utf8.count),
                            options: options,
                            matchParam: matchParam)
    }

    /**
     Search in a range of a string and return the first matching region.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: The matching region, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstMatch<T: StringProtocol>(in str: T, of utf8Range: Range<Int>, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> Region? {
        let region = try Region(with: self)
        let result = try str.withOnigurumaString { (start, count) throws -> OnigInt in
            let range = utf8Range.clamped(to: 0..<count)
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

    /**
     Find all matched region of the regular expression in the string.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: An array of all matched regions.
     - Throws: `OnigError`
     */
    public func matches<S: StringProtocol>(in str: S, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> [Region] {
        try self.matches(in: str,
                         of: 0...,
                         options: options,
                         matchParam: matchParam)
    }

    /**
     Find all matched region of the regular expression in the string.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: An array of all matched regions.
     - Throws: `OnigError`
     */
    public func matches<S: StringProtocol, R: RangeExpression>(in str: S, of utf8Range: R = 0... as! R, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> [Region] where R.Bound == Int {
        try self.matches(in: str,
                         of: utf8Range.relative(to: 0..<str.utf8.count),
                         options: options,
                         matchParam: matchParam)
    }

    /**
     Find all matched region of the regular expression in the string.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
     - Returns: An array of all matched regions.
     - Throws: `OnigError`
     */
    public func matches<S: StringProtocol>(in str: S, of utf8Range: Range<Int>, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> [Region] {
        var regions = [Region]()
        try self.enumerateMatches(in: str,
                                  of: utf8Range,
                                  options: options,
                                  matchParam: matchParam) { regions.append($1); return true }
        return regions
    }

    /**
     Enumerates the string and calling the closure with each matched region.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
        - body: The closure to call on each match.
        - index: The matched index of UTF-8 bytes.
        - region: The matched region.
     - Throws: `OnigError`
     */
    public func enumerateMatches<S: StringProtocol>(in str: S, options: SearchOptions = .none, matchParam: MatchParam = MatchParam(), body: (_ index: Int,  _ region: Region) throws -> Bool) throws {
        try self.enumerateMatches(in: str,
                                  of: 0...,
                                  options: options,
                                  matchParam: matchParam,
                                  body: body)
    }

    /**
     Enumerates the string and calling the closure with each matched region.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
        - body: The closure to call on each match.
        - index: The matched index of UTF-8 bytes.
        - region: The matched region.
     - Throws: `OnigError`
     */
    public func enumerateMatches<S: StringProtocol, R: RangeExpression>(in str: S, of utf8Range: R, options: SearchOptions = .none, matchParam: MatchParam = MatchParam(), body: (_ index: Int,  _ region: Region) throws -> Bool) throws where R.Bound == Int {
        try self.enumerateMatches(in: str,
                                  of: utf8Range.relative(to: 0..<str.utf8.count),
                                  options: options,
                                  matchParam: matchParam,
                                  body: body)
    }

    /**
     Enumerates the string and calling the closure with each matched region.
     - Note: Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - utf8Range: The range of UTF-8 bytes to search against. It will be clamped to the range of the whole string first.
        - option: The regex search options.
        - matchParam: Match parameter values (`matchStackLimit`, `retryLimitInMatch`, `retryLimitInSearch`)
        - body: The closure to call on each match.
        - index: The matched index of UTF-8 bytes.
        - region: The matched region.
     - Throws: `OnigError`
     */
    public func enumerateMatches<S: StringProtocol>(in str: S, of utf8Range: Range<Int>, options: SearchOptions = .none, matchParam: MatchParam = MatchParam(), body: (_ index: Int,  _ region: Region) throws -> Bool) throws {
        try str.withOnigurumaString { (start, count) throws in
            var range = utf8Range.clamped(to: 0..<count)
            while true {
                let region = try Region(with: self)
                let result = try callOnigFunction {
                    onig_search_with_param(self.rawValue,
                                           start,
                                           start.advanced(by: count),
                                           start.advanced(by: range.lowerBound),
                                           start.advanced(by: range.upperBound),
                                           region.rawValue,
                                           options.rawValue,
                                           matchParam.rawValue)
                }
                
                if result == ONIG_MISMATCH {
                    break
                }
                
                if try body(Int(result), region) == false {
                    break
                }

                let matchedRange = region.range
                if matchedRange.upperBound == range.lowerBound {
                    // empty match, move to next code unit
                    let codeUnitSize = Encoding.utf8.rawValue.pointee.mbc_enc_len(start.advanced(by: matchedRange.upperBound))
                    guard codeUnitSize > 0 else {
                        fatalError("Code unit size at \(matchedRange.upperBound) is 0")
                    }
                    range = (matchedRange.upperBound + Int(codeUnitSize)) ..< range.upperBound
                } else {
                    range = matchedRange.upperBound ..< range.upperBound
                }
            }
        }
    }
    
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
    
    /**
     Clean up oniguruma regex object and cacahed pattern bytes.
     */
    private func cleanUp() {
        if self.rawValue != nil {
            onig_free(self.rawValue)
            self.rawValue = nil
        }
        
        if self.patternBytes != nil {
            self.patternBytes = nil
        }
        
        if self.syntax != nil {
            self.syntax = nil
        }
    }
}

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

/// Names
extension Regex {
    /**
     Get the count of named groups of the pattern.
     */
    public var namedCaptureGroupCount: Int {
        return self.rawValue == nil ? 0 : Int(onig_number_of_names(self.rawValue))
    }

    /**
     Call `body` for each named capture group in the regex. Each callback gets the capture group name and capture group indexes.
     - TODO:
        Add iterator for named capture groups
     */
    public func forEachNamedCaptureGroup(_ body: @escaping (_ name: String, _ indexes: [Int]) -> Bool) {
        if self.rawValue == nil {
            return
        }

        typealias NameCallBackType = (String, [Int]) -> Bool
        var closureRef: Any = body
        
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

            guard let closure = closureRefPtr?.assumingMemoryBound(to: NameCallBackType.self).pointee else {
                fatalError("Failed to get callbacks")
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
    
    // TODO: onig_name_to_backref_number
    
    // TODO: onig_noname_group_capture_is_active
}
