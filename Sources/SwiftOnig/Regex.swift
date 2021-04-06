//
//  Regex.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig
import Foundation

public class Regex {
    internal private(set) var rawValue: OnigRegex?

    /**
     Cached regex pattern in UTF-8 bytes.
     - Note:
     Although the default underlying storage of swift `String` use UTF-8, and we could access it with `withCString`,
     but the lifetime of the pointers are only the scope of `withCString` closures, so keep a copy of the pattern to make sure
     the addresses used in oniguruma is always valid.
    */
    private var patternBytes: ContiguousArray<UInt8>!
    
    /**
     Keep a reference to the syntax to make sure the address to the syntax used in oniguruma is always valid.
     */
    private var syntax: Syntax!

    /**
     Create a `Regex` with given paattern, option and syntax.
     - Parameters:
        - pattern: Pattern used to create the regex.
        - option: `Options` used to create the regex.
        - syntax: `Syntax` used to create the regex.
     - Throws:
        `OnigError`
     */
    init<S: StringProtocol>(_ pattern: S, option: Options = .none, syntax: Syntax = .default) throws {
        self.patternBytes = ContiguousArray(pattern.utf8)
        self.syntax = syntax

        var error = OnigErrorInfo()
        let result = self.patternBytes.withUnsafeBufferPointer { bufPtr -> Int32 in
            // Make sure that `onig_new` isn't called by more than one thread at a time.
            onigQueue.sync {
                onig_new(&self.rawValue,
                         bufPtr.baseAddress,
                         bufPtr.baseAddress?.advanced(by: self.patternBytes.count),
                         option.rawValue,
                         Encoding.utf8.rawValue,
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
     Get the pattern string of the regular expression.
     */
    public var pattern: String {
        self.patternBytes.withUnsafeBufferPointer { patternBufPtr in
            String(bytes: patternBufPtr, encoding: String.Encoding.utf8) ?? ""
        }
    }

    /**
     Reset the regex with the  given pattern.
     - Parameters:
        - pattern: Pattern used to recreate the regex.
     - Throws:
        `OnigError`
     - Note:
        If there are any error thrown while recreating the regex, this regex will become invalid.
     */
    public func reset<T: StringProtocol>(_ pattern: T) throws {
        try self.reset(pattern, option: .none, syntax: Syntax.default)
    }
    
    /**
     Reset the regex with the  given pattern.
     - Parameters:
        - pattern: Pattern used to create the regex.
        - option: `Options` used to create the regex.
        - syntax: `Syntax` used to create the regex.
     - Throws:
        `OnigError`
     - Note:
        If there are any error thrown while recreating the regex, this regex will become invalid.
     */
    public func reset<T: StringProtocol>(_ pattern: T, option: Options, syntax: Syntax) throws {
        self.patternBytes = ContiguousArray(pattern.utf8)
        self.syntax = syntax
        var error = OnigErrorInfo()
        let result = self.patternBytes.withUnsafeBufferPointer { bufPtr -> Int32 in
            // Make sure that `onig_new` isn't called by more than one thread at a time.
            onigQueue.sync {
                onig_new_without_alloc(self.rawValue,
                                       bufPtr.baseAddress,
                                       bufPtr.baseAddress?.advanced(by: self.patternBytes.count),
                                       option.rawValue,
                                       &OnigEncodingUTF8,
                                       self.syntax.rawValue,
                                       &error)
            }
        }

        if result != ONIG_NORMAL {
            self.cleanUp()
            throw OnigError(result, onigErrorInfo: error)
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
        if self.rawValue == nil {
            return nil
        }

        let byteCount = str.utf8.count
        if utf8Offset < 0 || utf8Offset >= byteCount {
            return nil
        }

        let region = Region()
        let result = str.withCString { (cstr: UnsafePointer<Int8>) -> Int32 in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> Int32 in
                onig_match_with_param(self.rawValue,
                                      start,
                                      start.advanced(by: byteCount),
                                      start.advanced(by: utf8Offset),
                                      &region.rawValue,
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
        let result = try str.withOnigurumaString { (start, count) throws -> Int32 in
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
        
        return Int(truncatingIfNeeded: result)
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
        let region = Region()
        let result = try str.withOnigurumaString { (start, count) throws -> Int32 in
            let range = utf8Range.clamped(to: 0..<count)
            return try callOnigFunction {
                onig_search_with_param(self.rawValue,
                                       start,
                                       start.advanced(by: count),
                                       start.advanced(by: range.lowerBound),
                                       start.advanced(by: range.upperBound),
                                       &region.rawValue,
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
                let region = Region()
                let result = try callOnigFunction {
                    onig_search_with_param(self.rawValue,
                                           start,
                                           start.advanced(by: count),
                                           start.advanced(by: range.lowerBound),
                                           start.advanced(by: range.upperBound),
                                           &region.rawValue,
                                           options.rawValue,
                                           matchParam.rawValue)
                }
                
                if result == ONIG_MISMATCH {
                    break
                }
                
                if try body(Int(result), region) == false {
                    break
                }
                
                guard let matchedRange = region.utf8BytesRange(groupIndex: 0) else {
                    // matches but no region found???
                    break
                }

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
    public var captureCount: Int {
        return self.rawValue == nil ? 0 : Int(onig_number_of_captures(self.rawValue))
    }
    
    /**
     Get the count of capture hisotries of the pattern.
     */
    public var captureHistoryCount: Int {
        return self.rawValue == nil ? 0 : Int(onig_number_of_capture_histories(self.rawValue))
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
    public var nameCount: Int {
        return self.rawValue == nil ? 0 : Int(onig_number_of_names(self.rawValue))
    }

    // public func onig_foreach_name(_ reg: OnigRegex!, _ func: (@convention(c) (UnsafePointer<OnigUChar>?, UnsafePointer<OnigUChar>?, Int32, UnsafeMutablePointer<Int32>?, OnigRegex?, UnsafeMutableRawPointer?) -> Int32)!, _ arg: UnsafeMutableRawPointer!) -> Int32

    public typealias nameCallBackType = @convention(c) (String, [Int]) -> Bool

    /**
     Calls `callback` for each named group in the regex. Each callback gets the group name and group indices.
     - TODO:
        Add iterator for named groups
     */
    public func forEachName(_ callback: @escaping nameCallBackType) {
        if self.rawValue == nil {
            return
        }

        onig_foreach_name(self.rawValue, { (namePtr, nameEndPtr, groupCount, groupsPtr, _ /* regex */, context) -> Int32 in
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

            let callback = unsafeBitCast(context, to: nameCallBackType.self)

            if callback(name, groupIndice) {
                return ONIG_NORMAL
            } else {
                return ONIG_ABORT
            }
        }, unsafeBitCast(callback, to: UnsafeMutableRawPointer.self))
    }
}
