import Foundation

extension String {
    /// Returns whether the string contains at least one match of the regex.
    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options) != nil
    }

    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options, matchConfiguration: matchConfiguration) != nil
    }

    /// Returns all non-overlapping matches of the regex in forward search order.
    public func matches(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options)
    }

    public func matches(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options, matchConfiguration: matchConfiguration)
    }

    /// Returns the string ranges for all non-overlapping matches of the regex.
    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options).map(\.range)
    }

    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options, matchConfiguration: matchConfiguration).map(\.range)
    }

    /// Returns a copy of the string with every regex match replaced by the provided text.
    public func replacing(_ regex: Regex, with replacement: String, options: Regex.SearchOptions = .none) throws -> String {
        try replacing(regex, with: replacement, options: options, matchConfiguration: Regex.MatchConfiguration())
    }

    public func replacing(_ regex: Regex, with replacement: String, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> String {
        let matches = try matches(of: regex, options: options, matchConfiguration: matchConfiguration)
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

    public mutating func replace(_ regex: Regex, with replacement: String, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws {
        self = try replacing(regex, with: replacement, options: options, matchConfiguration: matchConfiguration)
    }

    /// Trims a single prefix match from the start of the string.
    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options, matchConfiguration: matchConfiguration) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    /// Splits the string on regex matches, omitting empty subsequences.
    public func split(separator regex: Regex, options: Regex.SearchOptions = .none) throws -> [Substring] {
        try split(separator: regex, options: options, matchConfiguration: Regex.MatchConfiguration())
    }

    public func split(separator regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> [Substring] {
        let separatorRanges = try ranges(of: regex, options: options, matchConfiguration: matchConfiguration)
        guard !separatorRanges.isEmpty else {
            return [self[...]]
        }

        var segments = [Substring]()
        var currentIndex = startIndex

        for range in separatorRanges {
            let segment = self[currentIndex..<range.lowerBound]
            if !segment.isEmpty {
                segments.append(segment)
            }
            currentIndex = range.upperBound
        }

        let trailing = self[currentIndex...]
        if !trailing.isEmpty {
            segments.append(trailing)
        }

        return segments
    }

    /// Returns the first string-native regex match.
    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options)
    }

    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options, matchConfiguration: matchConfiguration)
    }

    /// Returns a match only when it begins at the start of the string.
    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options)
    }

    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options, matchConfiguration: matchConfiguration)
    }

    /// Returns a match only when the regex covers the entire string.
    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options)
    }

    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options, matchConfiguration: matchConfiguration)
    }
}

extension Substring {
    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options) != nil
    }

    public func contains(_ regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Bool {
        try regex.firstStringMatch(in: self, options: options, matchConfiguration: matchConfiguration) != nil
    }

    public func matches(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options)
    }

    public func matches(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> [Regex.Match] {
        try regex.stringMatches(in: self, options: options, matchConfiguration: matchConfiguration)
    }

    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options).map(\.range)
    }

    public func ranges(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> [Range<String.Index>] {
        try matches(of: regex, options: options, matchConfiguration: matchConfiguration).map(\.range)
    }

    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    public func trimmingPrefix(_ regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Substring {
        if let match = try prefixMatch(of: regex, options: options, matchConfiguration: matchConfiguration) {
            return self[match.range.upperBound...]
        }

        return self[...]
    }

    public func split(separator regex: Regex, options: Regex.SearchOptions = .none) throws -> [Substring] {
        try split(separator: regex, options: options, matchConfiguration: Regex.MatchConfiguration())
    }

    public func split(separator regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> [Substring] {
        let separatorRanges = try ranges(of: regex, options: options, matchConfiguration: matchConfiguration)
        guard !separatorRanges.isEmpty else {
            return [self[...]]
        }

        var segments = [Substring]()
        var currentIndex = startIndex

        for range in separatorRanges {
            let segment = self[currentIndex..<range.lowerBound]
            if !segment.isEmpty {
                segments.append(segment)
            }
            currentIndex = range.upperBound
        }

        let trailing = self[currentIndex...]
        if !trailing.isEmpty {
            segments.append(trailing)
        }

        return segments
    }

    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options)
    }

    public func firstMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Regex.Match? {
        try regex.firstStringMatch(in: self, options: options, matchConfiguration: matchConfiguration)
    }

    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options)
    }

    public func prefixMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Regex.Match? {
        try regex.prefixStringMatch(in: self, options: options, matchConfiguration: matchConfiguration)
    }

    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options)
    }

    public func wholeMatch(of regex: Regex, options: Regex.SearchOptions = .none, matchConfiguration: Regex.MatchConfiguration) throws -> Regex.Match? {
        try regex.wholeStringMatch(in: self, options: options, matchConfiguration: matchConfiguration)
    }
}
