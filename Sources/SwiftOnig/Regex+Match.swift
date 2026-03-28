import Foundation

extension Regex {
    internal struct MatchMetadata: Sendable {
        let namedCaptureGroupNumbers: [String: [Int]]
    }

    public struct Match: Sendable, RandomAccessCollection {
        public typealias Index = Int
        public typealias Element = Capture?

        public struct Capture: Sendable {
            public let groupNumber: Int
            public let range: Range<String.Index>
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

        public var startIndex: Int {
            captures.startIndex
        }

        public var endIndex: Int {
            captures.endIndex
        }

        public var count: Int {
            captures.count
        }

        public var range: Range<String.Index> {
            precondition(count > 0, "Empty match")
            guard let capture = captures[0] else {
                preconditionFailure("Whole match capture missing")
            }
            return capture.range
        }

        public var substring: Substring {
            precondition(count > 0, "Empty match")
            guard let capture = captures[0] else {
                preconditionFailure("Whole match capture missing")
            }
            return capture.substring
        }

        public subscript(position: Int) -> Capture? {
            captures[position]
        }

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

    internal func stringMatches(in input: String, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> [Match] {
        let state = MatchCollectionState()
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            _ = try _enumerateMatches(in: supported,
                                      of: Self.fullByteRange,
                                      options: options,
                                      matchParam: matchParam) { _, _, region in
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

    internal func stringMatches(in input: Substring, options: SearchOptions = .none, matchParam: MatchParam = MatchParam()) throws -> [Match] {
        let state = MatchCollectionState()
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            _ = try _enumerateMatches(in: supported,
                                      of: Self.fullByteRange,
                                      options: options,
                                      matchParam: matchParam) { _, _, region in
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

    public func firstStringMatch(in input: String, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: nil) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func firstStringMatch(in input: String, options: SearchOptions = .none, matchParam: MatchParam) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func firstStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: nil) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    public func firstStringMatch(in input: Substring, options: SearchOptions = .none, matchParam: MatchParam) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    public func prefixStringMatch(in input: String, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: nil),
                  region.range.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func prefixStringMatch(in input: String, options: SearchOptions = .none, matchParam: MatchParam) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam),
                  region.range.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func prefixStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: nil),
                  region.range.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    public func prefixStringMatch(in input: Substring, options: SearchOptions = .none, matchParam: MatchParam) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _firstMatch(in: supported, of: Self.fullByteRange, options: options, matchParam: matchParam),
                  region.range.lowerBound == 0 else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    public func wholeStringMatch(in input: String, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchParam: nil) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func wholeStringMatch(in input: String, options: SearchOptions = .none, matchParam: MatchParam) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchParam: matchParam) else {
                return nil
            }

            return try Match(region: region, input: input[...])
        }
    }

    public func wholeStringMatch(in input: Substring, options: SearchOptions = .none) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchParam: nil) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }

    public func wholeStringMatch(in input: Substring, options: SearchOptions = .none, matchParam: MatchParam) throws -> Match? {
        try withSupportedOnigurumaInput(input, requestedEncoding: self.encoding) { supported in
            guard let region = try _wholeMatch(in: supported, options: options, matchParam: matchParam) else {
                return nil
            }

            return try Match(region: region, input: input)
        }
    }
}
