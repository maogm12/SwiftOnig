//
//  Regex.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

public class Regex {
    var rawValue: OnigRegex?

    convenience init<T: StringProtocol>(_ pattern: T) throws {
        try self.init(pattern, option: .none, syntax: Syntax.default)
    }

    init<T: StringProtocol>(_ pattern: T, option: Options, syntax: Syntax) throws {
        // We can use this later to get an error message to pass back
        // if regex creation fails.
        var error = OnigErrorInfo(enc: nil, par: nil, par_end: nil)

        // TODO add lock
        let byteCount = pattern.utf8.count
        let result = pattern.withCString { (patternCstr: UnsafePointer<Int8>) -> Int32 in
            patternCstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { patternStart in
                var rawSyntax = syntax.rawValue
                return onig_new(&self.rawValue,
                                patternStart,
                                patternStart.advanced(by: byteCount),
                                option.rawValue,
                                &OnigEncodingUTF8,
                                &rawSyntax,
                                &error)
            }
        }
        
        if result != ONIG_NORMAL {
            throw OnigError(result)
        }
    }

    deinit {
        onig_free(self.rawValue)
    }
    
    public func reset<T: StringProtocol>(_ pattern: T) throws {
        try self.reset(pattern, option: .none, syntax: Syntax.default)
    }
    
    public func reset<T: StringProtocol>(_ pattern: T, option: Options, syntax: Syntax) throws {
        // We can use this later to get an error message to pass back
        // if regex creation fails.
        var error = OnigErrorInfo(enc: nil, par: nil, par_end: nil)

        // TODO add lock
        let byteCount = pattern.utf8.count
        let result = pattern.withCString { (patternCstr: UnsafePointer<Int8>) -> Int32 in
            patternCstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { patternStart in
                var rawSyntax = syntax.rawValue
                return onig_new_without_alloc(self.rawValue,
                                              patternStart,
                                              patternStart.advanced(by: byteCount),
                                              option.rawValue,
                                              &OnigEncodingUTF8,
                                              &rawSyntax,
                                              &error)
            }
        }
        
        if result != ONIG_NORMAL {
            throw OnigError(result)
        }
    }

    /**
     Match string and returns true if and only if the regex matches the whole string given.
     - Parameters:
        - str: Target string to match against
     - Returns:
        `true` if and only if the regex matches the whole string given, otherwise `false`.
     */
    public func isMatch<T: StringProtocol>(_ str: T) throws -> Bool {
        let matchParam = try MatchParam()
        if let matchLen = try self.match(str, options: .none, region: nil, matchParam: matchParam) {
            return matchLen == str.utf8.count
        } else {
            return false
        }
    }
    
    /**
     Match string and return result and matching region. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to match against
     - Returns:
        The byte-position of the start of the match if the regex matches, `nil` if it doesn't match.
     - Throws: `OnigError`
     */
    public func match<T: StringProtocol>(_ str: T) throws -> Int? {
        let matchParam = try MatchParam()
        return try self.match(str, options: .none, region: nil, matchParam: matchParam)
    }

    /**
     Match string and return result and matching region. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to match against
        - option: The regex match options.
        - region: Address for return group match range info
        - matchParam: Match parameter values (match_stack_limit, retry_limit_in_match, retry_limit_in_search)
     - Returns:
        The byte-position of the start of the match if the regex matches, `nil` if it doesn't match.
     - Throws: `OnigError`
     */
    public func match<T: StringProtocol>(_ str: T, options: SearchOptions, region: Region?, matchParam: MatchParam) throws -> Int? {
        let byteCount = str.utf8.count
        let result = str.withCString { (cstr: UnsafePointer<Int8>) -> Int32 in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> Int32 in
                var onigRegion: UnsafeMutablePointer<OnigRegion>! = nil
                if region != nil {
                    onigRegion = UnsafeMutablePointer<OnigRegion>.allocate(capacity: 1)
                    onigRegion.pointee = region!.rawValue
                }
                let r = onig_match_with_param(self.rawValue,
                                             start,
                                             start.advanced(by: byteCount),
                                             start,
                                             onigRegion,
                                             options.rawValue,
                                             matchParam.rawValue)
                if region != nil {
                    region?.rawValue = onigRegion.pointee
                }
                return r
            }
        }
        
        if result >= 0 {
            return Int(result)
        } else if result == ONIG_MISMATCH {
            return nil
        }

        throw OnigError(result)
    }
    
    /**
     Search string and return search result and matching region. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
     - Returns: match position offset, or `nil` if nothing is found.
     - Throws: `OnigError`
     */
    public func search<T: StringProtocol>(_ str: T) throws -> Int? {
        let matchParam = try MatchParam()
        return try self.search(str, options: .none, region: nil, matchParam: matchParam)
    }
    
    /**
     Search string and return search result and matching region. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to search against
        - option: The regex search options.
        - region: Address for return group match range info
        - matchParam: Match parameter values (match_stack_limit, retry_limit_in_match, retry_limit_in_search)
     - Returns: match position offset, or `nil` if nothing is found.
     - Throws: `OnigError`
     */
    public func search<T: StringProtocol>(_ str: T, options: SearchOptions, region: Region?, matchParam: MatchParam) throws -> Int? {
        let byteCount = str.utf8.count
        let result = str.withCString { (cstr: UnsafePointer<Int8>) -> Int32 in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> Int32 in
                var onigRegion: UnsafeMutablePointer<OnigRegion>! = nil
                if region != nil {
                    onigRegion = UnsafeMutablePointer<OnigRegion>.allocate(capacity: 1)
                    onigRegion.pointee = region!.rawValue
                }
                
                let r = onig_search_with_param(self.rawValue,
                                             start,
                                             start.advanced(by: byteCount),
                                             start,
                                             start.advanced(by: byteCount),
                                             onigRegion,
                                             options.rawValue,
                                             matchParam.rawValue)
                
                if region != nil {
                    region?.rawValue = onigRegion.pointee
                }

                return r
            }
        }
        
        if result >= 0 {
            return Int(result)
        } else if result == ONIG_MISMATCH {
            return nil
        }

        throw OnigError(result)
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
     The number of named groups into regex.
     */
    public var captureNameCount: Int {
        return Int(onig_number_of_names(&self.rawValue))
    }

    // public func onig_foreach_name(_ reg: OnigRegex!, _ func: (@convention(c) (UnsafePointer<OnigUChar>?, UnsafePointer<OnigUChar>?, Int32, UnsafeMutablePointer<Int32>?, OnigRegex?, UnsafeMutableRawPointer?) -> Int32)!, _ arg: UnsafeMutableRawPointer!) -> Int32

    
}
