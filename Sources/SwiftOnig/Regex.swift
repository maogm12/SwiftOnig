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

    private static let regexNewlock = NSLock()

    /**
     Create a `Regex` with the given pattern.
     - Parameters:
        - pattern: Pattern used to create the regex.
     - Throws:
        `OnigError`
     */
    convenience init<T: StringProtocol>(_ pattern: T) throws {
        try self.init(pattern, option: .none, syntax: Syntax.default)
    }

    /**
     Create a `Regex` with given paattern, option and syntax.
     - Parameters:
        - pattern: Pattern used to create the regex.
        - option: `Options` used to create the regex.
        - syntax: `Syntax` used to create the regex.
     - Throws:
        `OnigError`
     */
    init<T: StringProtocol>(_ pattern: T, option: Options, syntax: Syntax) throws {
        self.patternBytes = ContiguousArray(pattern.utf8)
        var error = OnigErrorInfo()
        let result = self.patternBytes.withUnsafeBufferPointer { bufPtr -> Int32 in
            // Make sure that `onig_new` isn't called by more than one thread at a time.
            Regex.regexNewlock.lock()
            let onigResult = onig_new(&self.rawValue,
                                      bufPtr.baseAddress,
                                      bufPtr.baseAddress?.advanced(by: self.patternBytes.count),
                                      option.rawValue,
                                      &OnigEncodingUTF8,
                                      &syntax.rawValue,
                                      &error)
            Regex.regexNewlock.unlock()
            return onigResult
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
        var error = OnigErrorInfo()
        let result = self.patternBytes.withUnsafeBufferPointer { bufPtr -> Int32 in
            // Make sure that `onig_new` isn't called by more than one thread at a time.
            Regex.regexNewlock.lock()
            let onigResult = onig_new_without_alloc(self.rawValue,
                                                    bufPtr.baseAddress,
                                                    bufPtr.baseAddress?.advanced(by: self.patternBytes.count),
                                                    option.rawValue,
                                                    &OnigEncodingUTF8,
                                                    &syntax.rawValue,
                                                    &error)
            Regex.regexNewlock.unlock()
            return onigResult
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
    public func matchedByteCount<T: StringProtocol>(in str: T, from: Int = 0) -> Int? {
        try? self.match(in: str)?.matchedByteCount
    }

    /**
     Match string and return matched UTF-8 byte count. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to match against
        - from: The position to match against
        - option: The regex match options.
        - matchParam: Match parameter values (match_stack_limit, retry_limit_in_match, retry_limit_in_search)
     - Returns:
        A tuple of matched UTF-8 byte count and matching region, `nil` if it doesn't match.
     - Throws: `OnigError`
     */
    public func match<T: StringProtocol>(in str: T, from: Int = 0, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> (matchedByteCount: Int, region: Region)? {
        if self.rawValue == nil {
            return nil
        }

        let region = Region()
        let byteCount = str.utf8.count
        let result = str.withCString { (cstr: UnsafePointer<Int8>) -> Int32 in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> Int32 in
                onig_match_with_param(self.rawValue,
                                      start,
                                      start.advanced(by: byteCount),
                                      start.advanced(by: from),
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
     Search in the string and return the first index of matched position. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
     - Returns:
        First matched UTF-8 byte position offset, or `nil` if no match is found.
     */
    public func firstIndex<T: StringProtocol>(in str: T) -> Int? {
        try? self.search(in: str)?.firstIndex
    }

    /**
     Search string and return search result and matching region. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - option: The regex search options.
        - matchParam: Match parameter values (match_stack_limit, retry_limit_in_match, retry_limit_in_search)
     - Returns:
        Tuple of first matched UTF-8 byte position and matching region, or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func search<T: StringProtocol>(in str: T, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> (firstIndex: Int, region: Region)? {
        if self.rawValue == nil {
            return nil
        }

        let region = Region()
        let byteCount = str.utf8.count
        let result = str.withCString { (cstr: UnsafePointer<Int8>) -> Int32 in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> Int32 in
                onig_search_with_param(self.rawValue,
                                             start,
                                             start.advanced(by: byteCount),
                                             start,
                                             start.advanced(by: byteCount),
                                             &region.rawValue,
                                             options.rawValue,
                                             matchParam.rawValue)
            }
        }
        
        if result >= 0 {
            return (firstIndex: Int(result), region: region)
        } else if result == ONIG_MISMATCH {
            return nil
        }

        throw OnigError(result)
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
