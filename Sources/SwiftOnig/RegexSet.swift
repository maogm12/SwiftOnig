//
//  RegexSet.swift
//  
//
//  Created by Guangming Mao on 4/2/21.
//

import OnigurumaC

/**
 A wrapper of oniguruma `OnigRegSet` which represents a set of regular expressions.
 */
public struct RegexSet: Sendable {
    internal typealias OnigRegSet = OpaquePointer

    internal final class Storage: @unchecked Sendable {
        let rawValue: OnigRegSet
        let regexes: [Regex]

        init(regexes: [Regex]) throws {
            self.regexes = regexes

            var rawValue: OnigRegSet?
            onig_regset_new(&rawValue, 0, nil)
            guard let rawValue else {
                throw OnigError.memory
            }

            self.rawValue = rawValue
            do {
                for regex in regexes {
                    try callOnigFunction {
                        onig_regset_add(rawValue, regex.rawValue)
                    }
                }
            } catch {
                for index in (0..<regexes.count).reversed() {
                    onig_regset_replace(rawValue, OnigInt(index), nil)
                }
                onig_regset_free(rawValue)
                throw error
            }
        }

        deinit {
            for index in (0..<regexes.count).reversed() {
                onig_regset_replace(rawValue, OnigInt(index), nil)
            }
            onig_regset_free(rawValue)
        }
    }

    private static let fullByteRange: PartialRangeFrom<Int> = 0...
    private var storage: Storage

    internal var rawValue: OnigRegSet {
        storage.rawValue
    }

    private var regexes: [Regex] {
        storage.regexes
    }

    /**
     Create a `RegexSet` with a sequence of regular expressions.
     
     The encoding of each regular expressions should be the same.
     - Parameter regexes: A sequence of regular expressions.
     - Throws: `OnigError`
     */
    public init<S>(regexes: S) async throws where S: Sequence, S.Element == Regex {
        let regexes = [Regex](regexes)
        try Self.validateRegexes(regexes)
        try await Self.initializeRuntime(for: regexes)
        self.storage = try Storage(regexes: regexes)
    }

    /**
     Create a `RegexSet` with a sequence of string patterns.
     */
    @OnigurumaActor
    public init<S, P>(patterns: S,
                      options: Regex.Options = .none,
                      syntax: Syntax? = nil
    ) async throws where S: Sequence, S.Element == P, P: StringProtocol {
        var compiledRegexes = [Regex]()
        for pattern in patterns {
            compiledRegexes.append(try await Regex(pattern: pattern, options: options, syntax: syntax))
        }
        try Self.validateRegexes(compiledRegexes)
        self.storage = try Storage(regexes: compiledRegexes)
    }

    /**
     Create a `RegexSet` with a sequence of patterns.
     */
    @OnigurumaActor
    public init<S, P>(patternsBytes: S,
                      encoding: Encoding,
                      options: Regex.Options = .none,
                      syntax: Syntax? = nil
    ) async throws where S: Sequence, S.Element == P, P: Sequence, P.Element == UInt8 {
        var compiledRegexes = [Regex]()
        for patternBytes in patternsBytes {
            compiledRegexes.append(try await Regex(patternBytes: patternBytes, encoding: encoding, options: options, syntax: syntax))
        }
        try Self.validateRegexes(compiledRegexes)
        self.storage = try Storage(regexes: compiledRegexes)
    }

    private static func validateRegexes(_ regexes: [Regex]) throws {
        guard let firstEncoding = regexes.first?.encoding.rawValue else {
            return
        }

        guard regexes.dropFirst().allSatisfy({ $0.encoding.rawValue == firstEncoding }) else {
            throw OnigError.invalidArgument
        }

        guard regexes.allSatisfy({ !$0.options.contains(.findLongest) }) else {
            throw OnigError.invalidArgument
        }
    }

    private static func initializeRuntime(for regexes: [Regex]) async throws {
        if let firstRegex = regexes.first {
            try await OnigurumaActor.shared.ensureInitialized(encoding: firstRegex.encoding.rawValue)
        } else {
            try await OnigurumaActor.shared.ensureInitialized()
        }
    }

    private mutating func rebuild(with regexes: [Regex]) throws {
        try Self.validateRegexes(regexes)
        storage = try Storage(regexes: regexes)
    }

    /**
     The count of regular expressions.
     */
    public var count: Int {
        regexes.count
    }

    /**
     Append a regex to the set.
     */
    public mutating func append(_ regex: Regex) throws {
        var updated = regexes
        updated.append(regex)
        try rebuild(with: updated)
    }

    /**
     Replace the regex at the provided index.
     */
    public mutating func replace(at index: Int, with regex: Regex) throws {
        precondition(regexes.indices.contains(index), "Index out of bounds")
        var updated = regexes
        updated[index] = regex
        try rebuild(with: updated)
    }

    /**
     Remove the regex at the provided index.
     */
    public mutating func remove(at index: Int) throws {
        precondition(regexes.indices.contains(index), "Index out of bounds")
        var updated = regexes
        updated.remove(at: index)
        try rebuild(with: updated)
    }

    /**
     Search string and return the first matching region.
     */
    public func firstMatch<S>(in str: S,
                              lead: Lead = .positionLead,
                              options: Regex.SearchOptions = .none,
                              matchParams: [MatchParam]? = nil
    ) throws -> (regexIndex: Int, region: Region)? where S: OnigurumaString {
        try _firstMatch(in: str,
                        of: Self.fullByteRange,
                        lead: lead,
                        options: options,
                        matchParams: matchParams)
    }

    /**
     Search a range of string and return the first matching region.
     */
    public func firstMatch<S, R>(in str: S,
                                 of range: R,
                                 lead: Lead = .positionLead,
                                 options: Regex.SearchOptions = .none,
                                 matchParams: [MatchParam]? = nil
    ) throws -> (regexIndex: Int, region: Region)? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        try _firstMatch(in: str, of: range, lead: lead, options: options, matchParams: matchParams)
    }

    private func _firstMatch<S, R>(in str: S,
                                   of range: R,
                                   lead: Lead = .positionLead,
                                   options: Regex.SearchOptions = .none,
                                   matchParams: [MatchParam]? = nil
    ) throws -> (regexIndex: Int, region: Region)? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        guard let firstRegex = regexes.first else {
            return nil
        }

        if let matchParams {
            precondition(matchParams.count == regexes.count, "Match params count must equal regex count")
        }

        let result = try str.withOnigurumaString(requestedEncoding: firstRegex.encoding) { start, count throws -> OnigInt in
            var bytesIndex: OnigInt = 0
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)

            if let matchParams {
                return try Self.withRawMatchParams(matchParams) { rawParams in
                    onig_regset_search_with_param(rawValue,
                                                  start,
                                                  start.advanced(by: count),
                                                  start.advanced(by: range.lowerBound),
                                                  start.advanced(by: range.upperBound),
                                                  lead.onigRegSetLead,
                                                  options.rawValue,
                                                  rawParams.baseAddress,
                                                  &bytesIndex)
                }
            } else {
                return onig_regset_search(rawValue,
                                          start,
                                          start.advanced(by: count),
                                          start.advanced(by: range.lowerBound),
                                          start.advanced(by: range.upperBound),
                                          lead.onigRegSetLead,
                                          options.rawValue,
                                          &bytesIndex)
            }
        }
        
        if result < 0 {
            if result == ONIG_MISMATCH {
                return nil
            } else {
                throw OnigError(onigErrorCode: result)
            }
        } else {
            let onigRegion = onig_regset_get_region(rawValue, result)
            return (regexIndex: Int(result),
                    region: try Region(copying: onigRegion,
                                       regex: regexes[Int(result)],
                                       str: str))
        }
    }

    private static func withRawMatchParams<Result>(_ matchParams: [MatchParam],
                                                   _ body: (UnsafeMutableBufferPointer<OpaquePointer?>) throws -> Result) throws -> Result {
        var rawParams = Array<OpaquePointer?>()
        rawParams.reserveCapacity(matchParams.count)

        func run(_ index: Int) throws -> Result {
            if index == matchParams.count {
                return try rawParams.withUnsafeMutableBufferPointer { buffer in
                    try body(buffer)
                }
            }

            return try matchParams[index].withRawValue { rawValue in
                rawParams.append(rawValue)
                defer { rawParams.removeLast() }
                return try run(index + 1)
            }
        }

        return try run(0)
    }

    /**
     Async version of `firstMatch`.
     */
    public func firstMatch<S>(in str: S,
                              lead: Lead = .positionLead,
                              options: Regex.SearchOptions = .none,
                              matchParams: [MatchParam]? = nil
    ) async throws -> (regexIndex: Int, region: Region)? where S: OnigurumaString {
        try _firstMatch(in: str, of: Self.fullByteRange, lead: lead, options: options, matchParams: matchParams)
    }

    /**
     Async version of `firstMatch`.
     */
    public func firstMatch<S, R>(in str: S,
                                 of range: R,
                                 lead: Lead = .positionLead,
                                 options: Regex.SearchOptions = .none,
                                 matchParams: [MatchParam]? = nil
    ) async throws -> (regexIndex: Int, region: Region)? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        try _firstMatch(in: str, of: range, lead: lead, options: options, matchParams: matchParams)
    }

    /**
     Out loop element when performing search.
     */
    public enum Lead {
        case positionLead
        case regexLead
        case priorityToRegexOrder
        
        public var onigRegSetLead: OnigRegSetLead {
            switch self {
            case .positionLead:
                return ONIG_REGSET_POSITION_LEAD
            case .regexLead:
                return ONIG_REGSET_REGEX_LEAD
            case .priorityToRegexOrder:
                return ONIG_REGSET_PRIORITY_TO_REGEX_ORDER
            }
        }
    }
}

extension RegexSet: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Regex
    
    public var startIndex: Int {
        0
    }
    
    public var endIndex: Int {
        regexes.count
    }

    public subscript(position: Int) -> Regex {
        regexes[position]
    }
}
