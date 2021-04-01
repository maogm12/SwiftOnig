//
//  MatchParam.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

public class MatchParam {
    internal private(set) var rawValue: OpaquePointer!

    public init() {
        self.rawValue = onig_new_match_param()
    }

    deinit {
        onig_free_match_param(self.rawValue)
    }
    
    /**
     Set the fields to default values.
     */
    public func reset() {
        onig_initialize_match_param(self.rawValue)
    }

    /**
     Set a maximum number of match-stack depth. `0` means unlimited.
     - Parameters:
        - limit: number of limit
     - Throws: `OnigError`
        if `onig_set_match_stack_limit_size_of_match_param` doesn't return `ONIG_NORMAL`
     */
    public func setMatchStackLimitSize(limit: UInt32) throws {
        let result = onig_set_match_stack_limit_size_of_match_param(self.rawValue, limit)
        if result != ONIG_NORMAL {
            throw OnigError(result)
        }
    }

    /**
    Set a retry limit count of a match process.
     - Parameters:
        - limit: number of limit
     - Throws: `OnigError`
        if `onig_set_retry_limit_in_match_of_match_param` doesn't return `ONIG_NORMAL`
     */
    public func setRetryLimitInMatch(limit: UInt) throws {
        let result = onig_set_retry_limit_in_match_of_match_param(self.rawValue, limit)
        if result != ONIG_NORMAL {
            throw OnigError(result)
        }
    }
    
    /**
     Set a retry limit count of a search process. `0` means unlimited.
     - Parameters:
        - limit: number of limit
     - Throws: `OnigError`
        if `onig_set_retry_limit_in_search_of_match_param` doesn't return `ONIG_NORMAL`
     */
    public func setRetryLimitInSearch(limit: UInt) throws {
        let result = onig_set_retry_limit_in_search_of_match_param(self.rawValue, limit)
        if result != ONIG_NORMAL {
            throw OnigError(result)
        }
    }
}
