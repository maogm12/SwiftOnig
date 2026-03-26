//
//  MatchParam.swift
//  
//
//  Created by Guangming Mao on 3/27/21.
//

import OnigurumaC

public struct MatchParam: Sendable {
    internal let calloutState: MatchParamCalloutState
    private var matchStackLimitSize: UInt?
    private var retryLimitInMatch: UInt?
    private var retryLimitInSearch: UInt?

    public init() {
        self.calloutState = MatchParamCalloutState()
        self.matchStackLimitSize = nil
        self.retryLimitInMatch = nil
        self.retryLimitInSearch = nil
    }

    /**
     Set the fields to default values.
     */
    public mutating func reset() {
        matchStackLimitSize = nil
        retryLimitInMatch = nil
        retryLimitInSearch = nil
        calloutState.userData = nil
        calloutState.progressHandler = nil
        calloutState.retractionHandler = nil
    }

    /**
     Set the maximum number of match-stack depth of the `MatchParam`. `0` means unlimited.
     - Parameter newLimit: The new limit.
     */
    public mutating func setMatchStackLimitSize(to newLimit: UInt) {
        matchStackLimitSize = newLimit
    }

    /**
    Set the retry limit count of a match process of the `MatchParam`.
     - Parameter newLimit: The new limit.
     */
    public mutating func setRetryLimitInMatch(to newLimit: UInt) {
        retryLimitInMatch = newLimit
    }

    /**
     Set the retry limit count in a search process of the `MatchParam`. `0` means unlimited.
     - Parameter newLimit: The new limit.
     */
    public mutating func setRetryLimitInSearch(to newLimit: UInt) {
        retryLimitInSearch = newLimit
    }

    /**
     Set the Swift value exposed to per-match callout handlers as user data.
     */
    public mutating func setCalloutUserData(_ userData: (any Sendable)?) {
        calloutState.userData = userData
    }

    /**
     Register a progress callout handler for content callouts executed with this match parameter.
     */
    public mutating func setProgressCallout(_ handler: OnigurumaCalloutHandler?) {
        calloutState.progressHandler = handler
    }

    /**
     Register a retraction callout handler for content callouts executed with this match parameter.
     */
    public mutating func setRetractionCallout(_ handler: OnigurumaCalloutHandler?) {
        calloutState.retractionHandler = handler
    }

    internal func withRawValue<Result>(_ body: (OpaquePointer) throws -> Result) throws -> Result {
        guard let rawValue = onig_new_match_param() else {
            throw OnigError.memory
        }

        defer {
            onig_free_match_param(rawValue)
        }

        if let matchStackLimitSize {
            _ = onig_set_match_stack_limit_size_of_match_param(rawValue, OnigUInt(matchStackLimitSize))
        }

        if let retryLimitInMatch {
            _ = onig_set_retry_limit_in_match_of_match_param(rawValue, OnigULong(retryLimitInMatch))
        }

        if let retryLimitInSearch {
            _ = onig_set_retry_limit_in_search_of_match_param(rawValue, OnigULong(retryLimitInSearch))
        }

        if calloutState.progressHandler == nil {
            _ = onig_set_progress_callout_of_match_param(rawValue, nil)
        } else {
            _ = onig_set_progress_callout_of_match_param(rawValue, onigurumaCalloutCallback)
        }

        if calloutState.retractionHandler == nil {
            _ = onig_set_retraction_callout_of_match_param(rawValue, nil)
        } else {
            _ = onig_set_retraction_callout_of_match_param(rawValue, onigurumaCalloutCallback)
        }

        let statePointer = Unmanaged.passUnretained(calloutState).toOpaque()
        _ = onig_set_callout_user_data_of_match_param(rawValue, statePointer)
        return try body(rawValue)
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
