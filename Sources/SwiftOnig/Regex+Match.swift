import Foundation

extension Regex {
    internal struct MatchMetadata: Sendable {
        let namedCaptureGroupNumbers: [String: [Int]]
    }

    /// A string-native match result produced from a `String` or `Substring` search.
    ///
    /// Capture `0` is always the whole match.
    public struct Match: Sendable, RandomAccessCollection {
        public typealias Index = Int
        public typealias Element = Capture?

        /// A single capture group resolved into Swift string indices.
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

        /// The range of the whole match.
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
        public subscript(position: Int) -> Capture? {
            captures[position]
        }

        /// Returns all captures associated with a named capture group.
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

    public func firstStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

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

    public func prefixStringMatch(in input: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: matchConfiguration),
                  region.byteRange.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func prefixStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchConfiguration: nil),
                  region.byteRange.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

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

    public func wholeStringMatch(in input: String, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchConfiguration: matchConfiguration) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func wholeStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchConfiguration: nil) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    public func wholeStringMatch(in input: Substring, options: SearchOptions = .none, matchConfiguration: MatchConfiguration) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchConfiguration: matchConfiguration) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }
}
