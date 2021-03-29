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

    init<T: StringProtocol>(_ pattern: T, option: RegexOptions, syntax: Syntax) throws {
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
    
    public func reset<T: StringProtocol>(_ pattern: T, option: RegexOptions, syntax: Syntax) throws {
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

    /// Match String
    public func match<T: StringProtocol>(_ str: T) throws -> Bool {
        let matchParam = try MatchParam()
        return try self.match(str, at: 0, options: .none, region: nil, matchParam: matchParam)
    }
    
    /**
     Match string and return result and matching region. Do not pass invalid byte string in the regex character encoding.
     - Parameters:
        - str: Target string to match against
        - at: The byte index in the passed buffer to start matching
        - option: The regex match options.
        - region: Address for return group match range info
        - matchParam: Match parameter values (match_stack_limit, retry_limit_in_match, retry_limit_in_search)
     - Returns:
       `true` if the match succeeds, otherwise `false`
     - Throws: `OnigError`
     */
    public func match<T: StringProtocol>(_ str: T, at: Int, options: SearchOptions, region: Region?, matchParam: MatchParam) throws -> Bool {
        let byteCount = str.utf8.count
        if at > byteCount {
            throw OnigError.invalidArgument
        }

        let result = str.withCString { (cstr: UnsafePointer<Int8>) -> Int32 in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> Int32 in
                let onigRegion: UnsafeMutablePointer<OnigRegion>! = nil
                if region != nil {
                    onigRegion.pointee = region!.rawValue
                }
                return onig_match_with_param(self.rawValue,
                                             start,
                                             start.advanced(by: byteCount),
                                             start.advanced(by: at),
                                             onigRegion,
                                             options.rawValue,
                                             matchParam.rawValue)
            }
        }
        
        if result >= 0 {
            return true
        } else if result == ONIG_MISMATCH {
            return false
        }

        throw OnigError(result)
    }
}
