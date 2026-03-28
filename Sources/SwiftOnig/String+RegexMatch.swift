import Foundation

extension String {
    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options) != nil
    }

    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options, matchParam: matchParam) != nil
    }

    public func matches(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options)
    }

    public func matches(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options, matchParam: matchParam)
    }

    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options).map(\.range)
    }

    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options, matchParam: matchParam).map(\.range)
    }

    public func replacing(_ regex: Regex, with replacement: String, options: Regex.SearchOptions = .none) throws -> String {
        try replacing(regex, with: replacement, options: options, matchParam: MatchParam())
    }

    public func replacing(_ regex: Regex, with replacement: String, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> String {
        let matches = try matches(of: regex, options: options, matchParam: matchParam)
        guard !matches.isEmpty else {
            return self
        }

        var result = String()
        var currentIndex = startIndex

        for match in matches {
            result.append(contentsOf: self[currentIndex..<match.range.lowerBound])
            result.append(replacement)
            currentIndex = match.range.upperBound
        }

        result.append(contentsOf: self[currentIndex...])
        return result
    }

    public mutating func replace(_ regex: Regex, with replacement: String, options: Regex.SearchOptions = .none) throws {
        self = try replacing(regex, with: replacement, options: options)
    }

    public mutating func replace(_ regex: Regex, with replacement: String, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws {
        self = try replacing(regex, with: replacement, options: options, matchParam: matchParam)
    }

    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options, matchParam: matchParam) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options)
    }

    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options, matchParam: matchParam)
    }

    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options)
    }

    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options, matchParam: matchParam)
    }

    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options)
    }

    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options, matchParam: matchParam)
    }
}

extension Substring {
    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options) != nil
    }

    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options, matchParam: matchParam) != nil
    }

    public func matches(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options)
    }

    public func matches(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options, matchParam: matchParam)
    }

    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options).map(\.range)
    }

    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options, matchParam: matchParam).map(\.range)
    }

    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options, matchParam: matchParam) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options)
    }

    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options, matchParam: matchParam)
    }

    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options)
    }

    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options, matchParam: matchParam)
    }

    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options)
    }

    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options, matchParam: matchParam)
    }
}
