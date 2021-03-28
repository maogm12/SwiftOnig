//
//  MatchParam.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

public class MatchParam {
    var rawValue: OpaquePointer
    
    init?() {
        if let matchParam = onig_new_match_param() {
            onig_initialize_match_param(matchParam)
            self.rawValue = matchParam
        } else {
            return nil
        }
    }
    
    deinit {
        onig_free_match_param(self.rawValue)
    }

    /// Set the match stack limit
    public func setMatchStackLimitSize(limit: UInt32) {
        onig_set_match_stack_limit_size_of_match_param(self.rawValue, limit)
    }

    /// Set the retry limit in match
    public func setRetryLimitInMatch(limit: UInt) {
        onig_set_retry_limit_in_match_of_match_param(self.rawValue, limit)
    }
}
