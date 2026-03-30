import Foundation

extension Regex {
    internal struct MatchMetadata: Sendable {
        let namedCaptureGroupNumbers: [String: [Int]]
    }

    /// A string-native match result produced from a `String` or `Substring` search.
    ///
    /// `Regex.Match` wraps a raw `Region` and resolves all participating captures into
    /// `String.Index` ranges and `Substring` views. Capture `0` is always the whole match.
    public struct Match: Sendable, RandomAccessCollection {
        public typealias Index = Int
        public typealias Element = Capture?

        /// A single capture group resolved into Swift string indices.
        ///
        /// A `Capture` always refers back to the searched string without copying its contents.
        public struct Capture: Sendable {
            /// The numeric capture group index.
            public let groupNumber: Int
            /// The matched range in the searched string.
            public let range: Range<String.Index>
            /// The matched substring for this capture group.
            public let substring: Substring
        }

        private let input: Substring
        private let metadata: MatchMetadata
        private let captures: [Capture?]

        internal init(region: Region, input: Substring) throws {
            self.input = input
            self.metadata = region.regex.matchMetadata
            self.captures = try (0..<region.count).map { groupNumber -> Capture? in
                guard let subregion = region[groupNumber] else {
                    return nil
                }

                guard let range = subregion.range(in: input) else {
                    throw OnigError.stringIndexMappingFailed
                }

                return Capture(groupNumber: groupNumber,
                               range: range,
                               substring: input[range])
            }
        }

        /// The start of the capture collection.
        public var startIndex: Int {
            captures.startIndex
        }

        /// The end of the capture collection.
        public var endIndex: Int {
            captures.endIndex
        }

        /// The number of capture slots, including capture `0`.
        public var count: Int {
            captures.count
        }

        /// The range of the whole match in the searched string.
        public var range: Range<String.Index> {
            precondition(count > 0, "Empty match")
            guard let capture = captures[0] else {
                preconditionFailure("Whole match capture missing")
            }
            return capture.range
        }

        /// The substring for the whole match.
        public var substring: Substring {
            precondition(count > 0, "Empty match")
            guard let capture = captures[0] else {
                preconditionFailure("Whole match capture missing")
            }
            return capture.substring
        }

        /// Returns a capture by numeric group index.
        ///
        /// Capture `0` is the whole match. Optional captures that did not participate
        /// in the match return `nil`.
        public subscript(position: Int) -> Capture? {
            captures[position]
        }

        /// Returns all participating captures associated with a named capture group.
        ///
        /// A single Oniguruma capture name may map to multiple numeric groups.
        public func captures(named name: String) -> [Capture] {
            metadata.namedCaptureGroupNumbers[name, default: []].compactMap { groupNumber in
                guard groupNumber >= 0 && groupNumber < captures.count else {
                    return nil
                }
                return captures[groupNumber]
            }
        }
    }
}

extension Regex {
    private final class MatchCollectionState: @unchecked Sendable {
        var matches = [Match]()
        var error: Error?
    }

    internal func stringMatches(in input: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration = MatchConfiguration()) throws -> [Match] {
        let state = MatchCollectionState()
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            _ = try _enumerateMatches(in: supported,
                                      of: Self.fullByteRange,
                                      options: options,
                                      matchConfiguration: matchConfiguration) { _, _, region in
                do {
                    state.matches.append(try Match(region: region, input: input[...]))
                    return true
                } catch {
                    state.error = error
                    return false
                }
            }
        }

        if let error = state.error {
            throw error
        }

        return state.matches
    }

    internal func stringMatches(in input: Substring, options: SearchOptions = .none, matchConfiguration: MatchConfiguration = MatchConfiguration()) throws -> [Match] {
        let state = MatchCollectionState()
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            _ = try _enumerateMatches(in: supported,
                                      of: Self.fullByteRange,
                                      options: options,
                                      matchConfiguration: matchConfiguration) { _, _, region in
                do {
                    state.matches.append(try Match(region: region, input: input))
                    return true
                } catch {
                    state.error = error
                    return false
                }
            }
        }

        if let error = state.error {
            throw error
        }

        return state.matches
    }

    /// Returns the first string-native match found in a `String`.
    ///
    /// Use this regex-centric overload when you want a `Regex.Match` but prefer to start
    /// the call from a compiled `Regex` instead of `String.firstMatch(of:)`.
    public func firstStringMatch(in input: String, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    /// Returns the first string-native match found in a `String`, using a match configuration.
    public func firstStringMatch(in input: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    /// Returns the first string-native match found in a `Substring`.
    public func firstStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    /// Returns the first string-native match found in a `Substring`, using a match configuration.
    public func firstStringMatch(in input: Substring, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    /// Returns a match only when it begins at the start of the searched `String`.
    public func prefixStringMatch(in input: String, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil),
                  region.byteRange.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    /// Returns a prefix match for a `String`, using a match configuration.
    public func prefixStringMatch(in input: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration),
                  region.byteRange.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    /// Returns a match only when it begins at the start of the searched `Substring`.
    public func prefixStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil),
                  region.byteRange.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    /// Returns a prefix match for a `Substring`, using a match configuration.
    public func prefixStringMatch(in input: Substring, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration),
                  region.byteRange.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    /// Returns a match only when the regex covers the entire searched `String`.
    public func wholeStringMatch(in input: String, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchConfiguration: nil) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    /// Returns a whole-string match for a `String`, using a match configuration.
    public func wholeStringMatch(in input: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchConfiguration: matchConfiguration) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    /// Returns a match only when the regex covers the entire searched `Substring`.
    public func wholeStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchConfiguration: nil) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    /// Returns a whole-string match for a `Substring`, using a match configuration.
    public func wholeStringMatch(in input: Substring, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchConfiguration: matchConfiguration) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }
}
