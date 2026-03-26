//
//  RegexSet.swift
//  
//
//  Created by Guangming Mao on 4/2/21.
//

import OnigurumaC

/**
 A wrapper of oniguruma `OnigRegSet` which represents the a set of regular expressions.
 
 In `SwiftOnig`, `RegexSet` is supposed to be immutable, thoses APIs in oniguruma are wrapped:
 - `onig_regset_new`: wrapped in `init`.
 - `onig_regset_free`: wrapped in `deinit`.
 - `onig_regset_number_of_regex`, wrapped in `endIndex` of `RandomAccessCollection`.
 - `onig_regset_get_regex`: wrapped in `subscription(position:)`.
 - `onig_regset_get_region`: Used in `search(*)`.
 - `onig_regset_search`, `onig_regset_search_with_param` : Wrapped in `search(*)`.

 */
final public class RegexSet: @unchecked Sendable, OnigOwnedResource {
    internal typealias OnigRegSet = OpaquePointer
    private static let fullByteRange: PartialRangeFrom<Int> = 0...
    internal nonisolated(unsafe) var rawValue: OnigRegSet!
    
    /// Cached `Regex` objects
    private var regexes: [Regex]

    // MARK: init & deinit

    /**
     Create a `RegexSet` with a sequence of regular expressions.
     
     The encoding of each regular expressions should be the same.
     - Parameter regexes: A sequence of regular expressions.
     - Throws: `OnigError`
     */
    public init<S>(regexes: S) async throws where S: Sequence, S.Element == Regex {
        self.regexes = [Regex](regexes)
        try Self.validateRegexes(self.regexes)
        try await Self.initializeRuntime(for: self.regexes)
        try self.populateRawValue()
    }

    /**
     Create a `RegexSet` with a sequence of string patterns.

     As swift string uses UTF-8 as internal storage from swift 5, UTF-8 encoding (`Encoding.utf8`) will be used for swift string pattern.
     - Parameters:
         - patterns: Patterns used to create these regular expressions.
         - option: Options used to create these regular expressions.
         - syntax: Syntax used to create these regular expressions. If `nil`, `Syntax.default` will be used.
     - Throws: `OnigError`
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
        self.regexes = compiledRegexes

        try Self.validateRegexes(self.regexes)
        try self.populateRawValue()
    }

    /**
     Create a `RegexSet` with a sequence of patterns.

     - Parameters:
         - patterns: Patterns used to create these regular expressions.
         - encoding: Encoding used to create these regular expressions.
         - option: Options used to create these regular expressions.
         - syntax: Syntax used to create these regular expressions. If `nil`, `Syntax.default` will be used.
     - Throws: `OnigError`
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
        self.regexes = compiledRegexes

        try Self.validateRegexes(self.regexes)
        try self.populateRawValue()
    }

    deinit {
        self._cleanUp()
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

    private func populateRawValue() throws {
        onig_regset_new(&self.rawValue, 0, nil)
        for regex in self.regexes {
            do {
                try callOnigFunction {
                    onig_regset_add(self.rawValue, regex.rawValue)
                }
            } catch {
                self.cleanUpRawValue()
                throw error
            }
        }
    }

    private func rebuildRawValue(with regexes: [Regex]) throws {
        try Self.validateRegexes(regexes)
        self.cleanUpRawValue()
        self.regexes = regexes
        try self.populateRawValue()
    }

    /**
     The count of regular expressions.
     */
    public var count: Int {
        Int(onig_regset_number_of_regex(self.rawValue))
    }

    /**
     Append a regex to the set.
     */
    public func append(_ regex: Regex) throws {
        var updated = self.regexes
        updated.append(regex)
        try rebuildRawValue(with: updated)
    }

    /**
     Replace the regex at the provided index.
     */
    public func replace(at index: Int, with regex: Regex) throws {
        precondition(self.regexes.indices.contains(index), "Index out of bounds")
        var updated = self.regexes
        updated[index] = regex
        try rebuildRawValue(with: updated)
    }

    /**
     Remove the regex at the provided index.
     */
    public func remove(at index: Int) throws {
        precondition(self.regexes.indices.contains(index), "Index out of bounds")
        var updated = self.regexes
        updated.remove(at: index)
        try rebuildRawValue(with: updated)
    }

    // MARK: Match & Search

    /**
     Search string and return the first matching region.

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.

     - Parameters:
        - str: The target string to search against.
        - lead: Outer loop element, both `.positionLead` and `.regexLead` gurantee to return the *true* left most matched position, but in most cases `.positionLead` seems to be faster. `.priorityToRegexOrder` gurantee the returned regex index is the index of the *first* regular expression that coult match.
        - option: The regular expression search options.
        - matchParams: Match patameters, count **must** be equal to count of regular expressions.
     - Returns: A tuple of matched regular expression index and matching region. Or `nil` if no match is found.
     - Throws: `OnigError`
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

     If `str` conforms to `StringProtocol`, will search against the UTF-8 bytes of the string. Do not pass invalid bytes in the regular expression encoding.

     - Parameters:
        - str: The target string to search against.
        - range: The range of bytes to search against. It will be clamped to the range of the whole string first.
        - lead: Outer loop element, both `.positionLead` and `.regexLead` gurantee to return the *true* left most matched position, but in most cases `.positionLead` seems to be faster. `.priorityToRegexOrder` gurantee the returned regex index is the index of the *first* regular expression that coult match.
        - option: The regular expression search options.
        - matchParams: Match patameters, count **must** be equal to count of regular expressions.
     - Returns: A tuple of matched regular expression index and matching region. Or `nil` if no match is found.
     - Throws: `OnigError`
     */
    public func firstMatch<S, R>(in str: S,
                                 of range: R,
                                 lead: Lead = .positionLead,
                                 options: Regex.SearchOptions = .none,
                                 matchParams: [MatchParam]? = nil
    ) throws -> (regexIndex: Int, region: Region)? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        return try _firstMatch(in: str, of: range, lead: lead, options: options, matchParams: matchParams)
    }

    private func _firstMatch<S, R>(in str: S,
                                  of range: R,
                                  lead: Lead = .positionLead,
                                  options: Regex.SearchOptions = .none,
                                  matchParams: [MatchParam]? = nil
    ) throws -> (regexIndex: Int, region: Region)? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        guard let firstRegex = self.regexes.first else {
            return nil
        }
        let result = try str.withOnigurumaString(requestedEncoding: firstRegex.encoding) { (start, count) throws -> OnigInt in
            var bytesIndex: OnigInt = 0
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)
            if let matchParams = matchParams {
                let mps = UnsafeMutableBufferPointer<OpaquePointer?>.allocate(capacity: matchParams.count)
                _ = mps.initialize(from: matchParams.map{ $0.rawValue })
                defer {
                    mps.deallocate()
                }
                
                return onig_regset_search_with_param(self.rawValue,
                                                     start,
                                                     start.advanced(by: count),
                                                     start.advanced(by: range.lowerBound),
                                                     start.advanced(by: range.upperBound),
                                                     lead.onigRegSetLead,
                                                     options.rawValue,
                                                     mps.baseAddress,
                                                     &bytesIndex)
            } else {
                return onig_regset_search(self.rawValue,
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
            let onigRegion = onig_regset_get_region(self.rawValue, result)
            return(regexIndex: Int(result),
                   region: try Region(copying: onigRegion,
                                      regex: self.regexes[Int(result)],
                                      str: str))
        }
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
     Clean up oniruguma regset object and cached `Regex`.
     */
    private func _cleanUp() {
        self.cleanUpRawValue()
    }

    internal func releaseRawValue(_ rawValue: OnigRegSet) {
        for index in (0..<self.count).reversed() {
            // mark all regex object in the regset to be nil
            onig_regset_replace(rawValue, OnigInt(index), nil)
        }

        onig_regset_free(rawValue)
    }

    /**
     Out loop element when performing search.
     */
    public enum Lead {
        /**
         When performing the search, the outer loop is for positons of the string, once some of the regex matches from this position, it returns, so it gurantees the returned first matched index is indeed the first position some of the regex could match.
         */
        case positionLead
        /**
         When performing the search, the outer loop is for indexes of regex objects, and return the most left matched position, it also gurantees the return first matched index is the first position some of the regex could matches.
         */
        case regexLead
        /**
         When performing the search, the outer loop is for indexes of regex objects, once one regex matches, it returns, so it gurantees the returned matched regex is the first regex that matches, but the return first matched index might not be the first position some of the regex could matches.
         */
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

// MARK: RandomAccessCollection

extension RegexSet : RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Regex
    
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        return Int(onig_regset_number_of_regex(self.rawValue))
    }

    public subscript(position: Int) -> Regex {
        return self.regexes[position]
    }
}
