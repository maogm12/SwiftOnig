import Foundation

extension String {
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
