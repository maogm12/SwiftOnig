//
//  Regex.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

public struct Regex {
    var rawValue: OnigRegex?

    init?(pattern: String) {
        self.init(pattern: pattern, option: .none, syntax: Syntax.default)
    }

    init?(pattern: String, option: RegexOptions, syntax: Syntax) {
        // We can use this later to get an error message to pass back
        // if regex creation fails.
        var error = OnigErrorInfo(enc: nil, par: nil, par_end: nil)

        // TODO add lock
        let byteCount = pattern.utf8CString.count
        
        let result = pattern.withCString { (patternCstr: UnsafePointer<Int8>) -> Int32 in
            patternCstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { patternStart in
                var rawSyntax = syntax.rawValue
                return onig_new(&self.rawValue,
                    patternStart,
                    patternStart.advanced(by: pattern.utf8CString.count),
                    option.rawValue,
                    &OnigEncodingUTF8,
                    &rawSyntax,
                    &error)
            }
        }
        
        if result != ONIG_NORMAL {
            return nil
        }
    }
    
    /// Match String
    
    public func match(str: String, at: Int, options: SearchOptions, region: Region?) -> Int32 {
        let byteCount = str.utf8CString.count
        
        let errorCode = str.withCString { (cstr: UnsafePointer<Int8>) -> Int32 in
            cstr.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { start -> Int32 in
                return onig_match(self.rawValue,
                                  start,
                                  start.advanced(by: byteCount),
                                  start.advanced(by: at),
                                  nil,
                                  options.rawValue)
            }
        }
        
        return errorCode
    }
}
