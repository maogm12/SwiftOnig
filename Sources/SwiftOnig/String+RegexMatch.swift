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
