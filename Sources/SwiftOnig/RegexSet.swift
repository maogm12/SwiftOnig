//
//  RegexSet.swift
//  
//
//  Created by Guangming Mao on 4/2/21.
//

import OnigurumaC

/// A set of compiled regexes searched as a group through Oniguruma's regset support.
///
/// `RegexSet` is an advanced API for searching multiple compiled regexes against the same
/// input while preserving the identity of the regex that matched first.
public struct RegexSet: Sendable {
    internal typealias OnigRegSet = OpaquePointer

    /// A match returned from a `RegexSet` search.
    public struct Match: Sendable {
        /// The index of the regex that matched within the set.
        public let regexIndex: Int
        /// The compiled regex that matched.
        public let regex: Regex
        /// The raw region returned by the matching regex.
        public let region: Region
    }

    internal final class Storage: @unchecked Sendable {
        let rawValue: OnigRegSet
        var regexes: [Regex]

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

        func append(_ regex: Regex) throws {
            try callOnigFunction {
                onig_regset_add(rawValue, regex.rawValue)
            }
            regexes.append(regex)
        }

        func replace(at index: Int, with regex: Regex) throws {
            try callOnigFunction {
                onig_regset_replace(rawValue, OnigInt(index), regex.rawValue)
            }
            regexes[index] = regex
        }

        func remove(at index: Int) throws {
            try callOnigFunction {
                onig_regset_replace(rawValue, OnigInt(index), nil)
            }
            regexes.remove(at: index)
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

    /// Creates a regex set from already-compiled regexes.
    ///
    /// All regexes in the set must use the same encoding and must not use unsupported regset
    /// options such as `.findLongest`.
    public init<S>(regexes: S) throws where S: Sequence, S.Element == Regex {
        let regexes = [Regex](regexes)
        try Self.validateRegexes(regexes)
        try Self.initializeRuntime(for: regexes)
        self.storage = try Storage(regexes: regexes)
    }

    /// Creates a regex set from Swift string patterns compiled as UTF-8.
    public init<S, P>(patterns: S,
                      options: Regex.Options = .none,
                      syntax: Syntax? = nil
    ) throws where S: Sequence, S.Element == P, P: StringProtocol {
        var compiledRegexes = [Regex]()
        for pattern in patterns {
            compiledRegexes.append(try Regex(pattern: pattern, options: options, syntax: syntax))
        }
        try Self.validateRegexes(compiledRegexes)
        self.storage = try Storage(regexes: compiledRegexes)
    }

    /// Creates a regex set from encoded pattern bytes in a specific encoding.
    public init<S, P>(patternsBytes: S,
                      encoding: Encoding,
                      options: Regex.Options = .none,
                      syntax: Syntax? = nil
    ) throws where S: Sequence, S.Element == P, P: Sequence, P.Element == UInt8 {
        var compiledRegexes = [Regex]()
        for patternBytes in patternsBytes {
            compiledRegexes.append(try Regex(patternBytes: patternBytes, encoding: encoding, options: options, syntax: syntax))
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

    private static func initializeRuntime(for regexes: [Regex]) throws {
        if let firstRegex = regexes.first {
            try OnigurumaBootstrap.ensureInitialized(encoding: firstRegex.encoding.rawValue)
        } else {
            try OnigurumaBootstrap.ensureInitialized()
        }
    }

    private mutating func rebuild(with regexes: [Regex]) throws {
        try Self.validateRegexes(regexes)
        storage = try Storage(regexes: regexes)
    }

    private mutating func ensureUniqueStorage() throws {
        if isKnownUniquelyReferenced(&storage) {
            return
        }

        storage = try Storage(regexes: regexes)
    }

    /// The number of regexes currently stored in the set.
    public var count: Int {
        regexes.count
    }

    /// Appends a compiled regex to the set.
    public mutating func append(_ regex: Regex) throws {
        try Self.validateRegexes(regexes + [regex])
        try ensureUniqueStorage()
        try storage.append(regex)
    }

    /// Replaces the regex at the provided index.
    public mutating func replace(at index: Int, with regex: Regex) throws {
        precondition(regexes.indices.contains(index), "Index out of bounds")
        var updated = regexes
        updated[index] = regex
        try Self.validateRegexes(updated)
        try ensureUniqueStorage()
        try storage.replace(at: index, with: regex)
    }

    /// Removes the regex at the provided index.
    public mutating func remove(at index: Int) throws {
        precondition(regexes.indices.contains(index), "Index out of bounds")
        try ensureUniqueStorage()
        try storage.remove(at: index)
    }

    /// Returns the first regex in the set that matches the provided input.
    ///
    /// The returned `Match` includes both the matching regex index and the raw `Region`
    /// produced by that regex.
    public func firstMatch<S>(in str: S,
                              lead: Lead = .positionLead,
                              options: Regex.SearchOptions = .none,
                              matchConfigurations: [Regex.MatchConfiguration]? = nil
    ) throws -> Match? {
        guard let firstRegex = regexes.first else {
            return nil
        }

        return try withSupportedOnigurumaInput(str, requestedEncoding: firstRegex.encoding) { supported in
            try _firstMatch(in: supported,
                            of: Self.fullByteRange,
                            lead: lead,
                            options: options,
                            matchConfigurations: matchConfigurations)
        }
    }

    /// Returns the first regex in the set that matches within a raw byte range.
    ///
    /// The search range is interpreted in encoded byte offsets and clamped to the actual
    /// encoded input length before searching.
    public func firstMatch<S, R>(in str: S,
                                 of range: R,
                                 lead: Lead = .positionLead,
                                 options: Regex.SearchOptions = .none,
                                 matchConfigurations: [Regex.MatchConfiguration]? = nil
    ) throws -> Match? where R: RangeExpression, R.Bound == Int {
        guard let firstRegex = regexes.first else {
            return nil
        }

        return try withSupportedOnigurumaInput(str, requestedEncoding: firstRegex.encoding) { supported in
            try _firstMatch(in: supported, of: range, lead: lead, options: options, matchConfigurations: matchConfigurations)
        }
    }

    private func _firstMatch<S, R>(in str: S,
                                   of range: R,
                                   lead: Lead = .positionLead,
                                   options: Regex.SearchOptions = .none,
                                   matchConfigurations: [Regex.MatchConfiguration]? = nil
    ) throws -> Match? where S: OnigurumaString, R: RangeExpression, R.Bound == Int {
        guard let firstRegex = regexes.first else {
            return nil
        }

        if let matchConfigurations {
            precondition(matchConfigurations.count == regexes.count, "Match configurations count must equal regex count")
        }

        let result = try str.withOnigurumaString(requestedEncoding: firstRegex.encoding) { start, count throws -> OnigInt in
            var bytesIndex: OnigInt = 0
            let range = range.relative(to: 0..<count).clamped(to: 0..<count)

            if let matchConfigurations {
                return try Self.withRawMatchConfigurations(matchConfigurations) { rawParams in
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
            let regexIndex = Int(result)
            let regex = regexes[regexIndex]
            return Match(regexIndex: regexIndex,
                         regex: regex,
                         region: try Region(copying: onigRegion,
                                            regex: regex,
                                            str: str))
        }
    }

    private static func withRawMatchConfigurations<Result>(_ matchConfigurations: [Regex.MatchConfiguration],
                                                           _ body: (UnsafeMutableBufferPointer<OpaquePointer?>) throws -> Result) throws -> Result {
        var rawParams = Array<OpaquePointer?>()
        rawParams.reserveCapacity(matchConfigurations.count)

        func run(_ index: Int) throws -> Result {
            if index == matchConfigurations.count {
                return try rawParams.withUnsafeMutableBufferPointer { buffer in
                    try body(buffer)
                }
            }

            return try matchConfigurations[index].withRawValue { rawValue in
                rawParams.append(rawValue)
                defer { rawParams.removeLast() }
                return try run(index + 1)
            }
        }

        return try run(0)
    }

    /**
     Out loop element when performing search.
     */
    public enum Lead: Sendable {
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
