//
//  MatchParam.swift
//
//
//  Created by Guangming Mao on 3/27/21.
//

import OnigurumaC

internal final class MatchConfigurationCalloutState: @unchecked Sendable {
    let progressHandler: OnigurumaCalloutHandler?
    let retractionHandler: OnigurumaCalloutHandler?

    init(progressHandler: OnigurumaCalloutHandler?, retractionHandler: OnigurumaCalloutHandler?) {
        self.progressHandler = progressHandler
        self.retractionHandler = retractionHandler
    }
}

extension Regex {
    public struct MatchConfiguration: Sendable {
        public let matchStackLimitSize: UInt?
        public let retryLimitInMatch: UInt?
        public let retryLimitInSearch: UInt?
        public let progressHandler: OnigurumaCalloutHandler?
        public let retractionHandler: OnigurumaCalloutHandler?

        public init(
            matchStackLimitSize: UInt? = nil,
            retryLimitInMatch: UInt? = nil,
            retryLimitInSearch: UInt? = nil,
            progressHandler: OnigurumaCalloutHandler? = nil,
            retractionHandler: OnigurumaCalloutHandler? = nil
        ) {
            self.matchStackLimitSize = matchStackLimitSize
            self.retryLimitInMatch = retryLimitInMatch
            self.retryLimitInSearch = retryLimitInSearch
            self.progressHandler = progressHandler
            self.retractionHandler = retractionHandler
        }

        public func settingMatchStackLimitSize(_ newLimit: UInt?) -> Self {
            Self(matchStackLimitSize: newLimit,
                 retryLimitInMatch: retryLimitInMatch,
                 retryLimitInSearch: retryLimitInSearch,
                 progressHandler: progressHandler,
                 retractionHandler: retractionHandler)
        }

        public func settingRetryLimitInMatch(_ newLimit: UInt?) -> Self {
            Self(matchStackLimitSize: matchStackLimitSize,
                 retryLimitInMatch: newLimit,
                 retryLimitInSearch: retryLimitInSearch,
                 progressHandler: progressHandler,
                 retractionHandler: retractionHandler)
        }

        public func settingRetryLimitInSearch(_ newLimit: UInt?) -> Self {
            Self(matchStackLimitSize: matchStackLimitSize,
                 retryLimitInMatch: retryLimitInMatch,
                 retryLimitInSearch: newLimit,
                 progressHandler: progressHandler,
                 retractionHandler: retractionHandler)
        }

        public func settingProgressHandler(_ handler: OnigurumaCalloutHandler?) -> Self {
            Self(matchStackLimitSize: matchStackLimitSize,
                 retryLimitInMatch: retryLimitInMatch,
                 retryLimitInSearch: retryLimitInSearch,
                 progressHandler: handler,
                 retractionHandler: retractionHandler)
        }

        public func settingRetractionHandler(_ handler: OnigurumaCalloutHandler?) -> Self {
            Self(matchStackLimitSize: matchStackLimitSize,
                 retryLimitInMatch: retryLimitInMatch,
                 retryLimitInSearch: retryLimitInSearch,
                 progressHandler: progressHandler,
                 retractionHandler: handler)
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

            if progressHandler == nil {
                _ = onig_set_progress_callout_of_match_param(rawValue, nil)
            } else {
                _ = onig_set_progress_callout_of_match_param(rawValue, onigurumaCalloutCallback)
            }

            if retractionHandler == nil {
                _ = onig_set_retraction_callout_of_match_param(rawValue, nil)
            } else {
                _ = onig_set_retraction_callout_of_match_param(rawValue, onigurumaCalloutCallback)
            }

            let state = MatchConfigurationCalloutState(progressHandler: progressHandler,
                                                       retractionHandler: retractionHandler)
            let statePointer = Unmanaged.passRetained(state).toOpaque()
            defer {
                Unmanaged<MatchConfigurationCalloutState>.fromOpaque(statePointer).release()
            }
            _ = onig_set_callout_user_data_of_match_param(rawValue, statePointer)
            return try body(rawValue)
        }
    }
}
