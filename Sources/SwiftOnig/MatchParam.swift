//
//  MatchParam.swift
//  
//
//  Created by Guangming Mao on 3/27/21.
//

import OnigurumaC

public class MatchParam {
    internal private(set) var rawValue: OpaquePointer!
    internal let calloutState = MatchParamCalloutState()

    public init() {
        self.rawValue = onig_new_match_param()
        let statePointer = Unmanaged.passUnretained(calloutState).toOpaque()
        onig_set_callout_user_data_of_match_param(self.rawValue, statePointer)
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
     Set the maximum number of match-stack depth of the `MatchParam`. `0` means unlimited.
     - Parameter newLimit: The new limit.
     */
    public func setMatchStackLimitSize(to newLimit: UInt) {
        onig_set_match_stack_limit_size_of_match_param(self.rawValue, OnigUInt(newLimit))
    }

    /**
    Set the retry limit count of a match process of the `MatchParam`.
     - Parameter newLimit: The new limit.
     */
    public func setRetryLimitInMatch(to newLimit: UInt) {
        onig_set_retry_limit_in_match_of_match_param(self.rawValue, OnigULong(newLimit))
    }

    /**
     Set the retry limit count in a search process of the `MatchParam`. `0` means unlimited.
     - Parameter newLimit: The new limit.
     */
    public func setRetryLimitInSearch(to newLimit: UInt) {
        onig_set_retry_limit_in_search_of_match_param(self.rawValue, OnigULong(newLimit))
    }

    /**
     Set the Swift value exposed to per-match callout handlers as user data.
     */
    public func setCalloutUserData(_ userData: (any Sendable)?) {
        calloutState.userData = userData
    }

    /**
     Register a progress callout handler for content callouts executed with this match parameter.
     */
    public func setProgressCallout(_ handler: OnigurumaCalloutHandler?) {
        calloutState.progressHandler = handler
        if handler == nil {
            onig_set_progress_callout_of_match_param(self.rawValue, nil)
        } else {
            onig_set_progress_callout_of_match_param(self.rawValue, onigurumaCalloutCallback)
        }
    }

    /**
     Register a retraction callout handler for content callouts executed with this match parameter.
     */
    public func setRetractionCallout(_ handler: OnigurumaCalloutHandler?) {
        calloutState.retractionHandler = handler
        if handler == nil {
            onig_set_retraction_callout_of_match_param(self.rawValue, nil)
        } else {
            onig_set_retraction_callout_of_match_param(self.rawValue, onigurumaCalloutCallback)
        }
    }
    
    /**
     Get or set the default value of maximum number of stack size, `0` means unlimited.
     */
    @OnigurumaActor
    public static var defaultMatchStackLimitSize: UInt {
        get {
            UInt(onig_get_match_stack_limit_size())
        }
        
        set {
            onig_set_match_stack_limit_size(OnigUInt(newValue))
        }
    }
    
    /**
     Get or set the default value of retry counts in a matching process., `0` means unlimited. The initial default value is `10000000`.
     */
    @OnigurumaActor
    public static var defaultRetryLimitInMatch: UInt {
        get {
            UInt(onig_get_retry_limit_in_match())
        }
        
        set {
            onig_set_retry_limit_in_match(OnigULong(newValue))
        }
    }

    /**
     Get or set the default value of retry counts in a matching process., `0` means unlimited.
     */
    @OnigurumaActor
    public static var defaultRetryLimitInSearch: UInt {
        get {
            UInt(onig_get_retry_limit_in_search())
        }
        
        set {
            onig_set_retry_limit_in_search(OnigULong(newValue))
        }
    }
}
