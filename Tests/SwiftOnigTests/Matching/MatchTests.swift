import Testing
@testable import SwiftOnig

@Suite("Match Tests")
struct MatchTests {
    private static func utf16LittleEndianBytes(_ string: String) -> [UInt8] {
        string.utf16.flatMap { codeUnit in
            [UInt8(codeUnit & 0xff), UInt8(codeUnit >> 8)]
        }
    }

    @Test("Regex.Match wraps String search results")
    func firstStringMatch() async throws {
        let regex = try Regex(pattern: #"(?<word>\w+)-(?<digits>\d+)"#)
        let input = "prefix item-123 suffix"

        let match = try #require(try regex.firstStringMatch(in: input))
        #expect(match.range == input.range(of: "item-123"))
        #expect(match.substring == "item-123")
        #expect(match.count == 3)
        #expect(match[0]?.substring == match.substring)
        #expect(match[1]?.substring == "item")
        #expect(match[2]?.substring == "123")
        #expect(match.captures(named: "word").map(\.substring) == ["item"])
        #expect(match.captures(named: "digits").map(\.substring) == ["123"])
    }

    @Test("Regex.Match supports Substring inputs")
    func substringInput() async throws {
        let regex = try Regex(pattern: #"\d+"#)
        let input = "aa11bb22"
        let slice = input[input.index(input.startIndex, offsetBy: 2)...]

        let match = try #require(try regex.firstStringMatch(in: slice))
        #expect(match.substring == "11")
        #expect(match.range.lowerBound == slice.startIndex)
        #expect(match.startIndex == 0)
        #expect(match.endIndex == 1)
    }

    @Test("Prefix and whole string match helpers")
    func prefixAndWholeStringMatch() async throws {
        let regex = try Regex(pattern: #"\d+"#)

        #expect(try regex.prefixStringMatch(in: "123abc")?.substring == "123")
        #expect(try regex.prefixStringMatch(in: "abc123") == nil)
        #expect(try regex.wholeStringMatch(in: "123")?.substring == "123")
        #expect(try regex.wholeStringMatch(in: "123abc") == nil)
    }

    @Test("String and Substring expose native-style match APIs")
    func stringNativeEntryPoints() async throws {
        let regex = try Regex(pattern: #"(?<word>\w+)-(?<digits>\d+)"#)
        let input = "prefix item-123 suffix"
        let slice = input[input.index(input.startIndex, offsetBy: 7)...]

        let stringMatch = try #require(try input.firstMatch(of: regex))
        #expect(stringMatch.substring == "item-123")
        #expect(stringMatch.captures(named: "digits").map(\.substring) == ["123"])

        let sliceMatch = try #require(try slice.prefixMatch(of: regex))
        #expect(sliceMatch.substring == "item-123")
        #expect(try input.wholeMatch(of: regex) == nil)
    }

    @Test("String and Substring expose regex contains")
    func stringNativeContains() async throws {
        let regex = try Regex(pattern: #"\d+"#)
        let missRegex = try Regex(pattern: #"xyz"#)
        let input = "prefix 123 suffix"
        let slice = input[input.index(input.startIndex, offsetBy: 7)...]

        #expect(try input.contains(regex))
        #expect(try !input.contains(missRegex))
        #expect(try slice.contains(regex))
        #expect(try !"prefix".contains(regex))
    }

    @Test("String-native regex APIs support MatchConfiguration overloads")
    func stringNativeMatchConfigurationOverloads() async throws {
        let regex = try Regex(pattern: #"\d+"#)
        let matchConfiguration = Regex.MatchConfiguration(
            matchStackLimitSize: 1_000,
            retryLimitInMatch: 1_000,
            retryLimitInSearch: 1_000
        )
        let input = "aa11bb22"
        let slice = input[input.index(input.startIndex, offsetBy: 2)...]

        #expect(try input.contains(regex, matchConfiguration: matchConfiguration))
        #expect(try input.firstMatch(of: regex, matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try input.prefixMatch(of: regex, matchConfiguration: matchConfiguration) == nil)
        #expect(try "11".wholeMatch(of: regex, matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try input.matches(of: regex, matchConfiguration: matchConfiguration).map(\.substring) == ["11", "22"])
        #expect(try input.ranges(of: regex, matchConfiguration: matchConfiguration).map { input[$0] } == ["11", "22"])

        #expect(try slice.contains(regex, matchConfiguration: matchConfiguration))
        #expect(try slice.firstMatch(of: regex, matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try slice.prefixMatch(of: regex, matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try slice.wholeMatch(of: regex, matchConfiguration: matchConfiguration) == nil)
        #expect(try slice.matches(of: regex, matchConfiguration: matchConfiguration).map(\.substring) == ["11", "22"])
        #expect(try slice.ranges(of: regex, matchConfiguration: matchConfiguration).map { slice[$0] } == ["11", "22"])
    }

    @Test("String and Substring expose regex matches and ranges")
    func stringNativeMatchesAndRanges() async throws {
        let regex = try Regex(pattern: #"(?<digits>\d+)"#)
        let input = "aa11bb22cc333"
        let slice = input[input.index(input.startIndex, offsetBy: 2)...]

        let matches = try input.matches(of: regex)
        #expect(matches.map(\.substring) == ["11", "22", "333"])
        #expect(matches.map { $0.captures(named: "digits").map(\.substring) } == [["11"], ["22"], ["333"]])

        let ranges = try input.ranges(of: regex)
        #expect(ranges.map { input[$0] } == ["11", "22", "333"])
        #expect(ranges == matches.map(\.range))

        let sliceMatches = try slice.matches(of: regex)
        #expect(sliceMatches.map(\.substring) == ["11", "22", "333"])

        let sliceRanges = try slice.ranges(of: regex)
        #expect(sliceRanges.map { slice[$0] } == ["11", "22", "333"])
    }

    @Test("String exposes regex replacing")
    func stringReplacing() async throws {
        let regex = try Regex(pattern: #"\d+"#)

        #expect(try "aa11bb22cc333".replacing(regex, with: "#") == "aa#bb#cc#")
        #expect(try "prefix".replacing(regex, with: "#") == "prefix")
        #expect(try "你好123世界45".replacing(regex, with: "-") == "你好-世界-")
    }

    @Test("String exposes mutating regex replace")
    func stringReplace() async throws {
        let regex = try Regex(pattern: #"\d+"#)
        var input = "aa11bb22cc333"
        try input.replace(regex, with: "#")
        #expect(input == "aa#bb#cc#")

        var untouched = "prefix"
        try untouched.replace(regex, with: "#")
        #expect(untouched == "prefix")

        var withParams = "11aa22"
        let matchConfiguration = Regex.MatchConfiguration(retryLimitInSearch: 1_000)
        try withParams.replace(regex, with: "#", matchConfiguration: matchConfiguration)
        #expect(withParams == "#aa#")
    }

    @Test("String and Substring expose trimmingPrefix")
    func stringTrimmingPrefix() async throws {
        let regex = try Regex(pattern: #"\d+"#)
        let matchConfiguration = Regex.MatchConfiguration(retryLimitInSearch: 1_000)

        #expect(try "123abc".trimmingPrefix(regex) == "abc")
        #expect(try "abc123".trimmingPrefix(regex) == "abc123")
        #expect(try "123abc".trimmingPrefix(regex, matchConfiguration: matchConfiguration) == "abc")
        #expect(try "abc123".trimmingPrefix(regex, matchConfiguration: matchConfiguration) == "abc123")

        let input = "0012-item"
        let slice = input[input.startIndex...]
        #expect(try slice.trimmingPrefix(regex) == "-item")
        #expect(try slice.trimmingPrefix(regex, matchConfiguration: matchConfiguration) == "-item")
        #expect(try "item"[...].trimmingPrefix(regex, matchConfiguration: matchConfiguration) == "item")
    }

    @Test("String and Substring expose regex split")
    func stringSplit() async throws {
        let comma = try Regex(pattern: ",")
        let digits = try Regex(pattern: #"\d+"#)
        let matchConfiguration = Regex.MatchConfiguration(retryLimitInSearch: 1_000)

        #expect(try "a,,b,".split(separator: comma) == ["a", "b"])
        #expect(try ",,".split(separator: comma) == [])
        #expect(try "a1b22c".split(separator: digits) == ["a", "b", "c"])
        #expect(try ",,"[...].split(separator: comma, matchConfiguration: matchConfiguration) == [])

        let input = "1a22b"
        let slice = input[input.index(after: input.startIndex)...]
        #expect(try slice.split(separator: digits) == ["a", "b"])
        #expect(try slice.split(separator: digits, matchConfiguration: matchConfiguration) == ["a", "b"])
    }

    @Test("String-native APIs handle empty and missing matches consistently")
    func emptyAndMissingStringResults() async throws {
        let regex = try Regex(pattern: #"\d+"#)
        let named = try Regex(pattern: #"(?<digits>\d+)"#)

        #expect(try "abc".matches(of: regex).isEmpty)
        #expect(try "abc".ranges(of: regex).isEmpty)
        #expect(try "abc".replacing(regex, with: "#") == "abc")
        #expect(try "abc".split(separator: regex) == ["abc"])
        #expect(try "abc".trimmingPrefix(regex) == "abc")

        let match = try #require(try "abc123".firstMatch(of: named))
        #expect(match.captures(named: "missing").isEmpty)
    }

    @Test("Regex string-native helpers support MatchConfiguration overloads")
    func regexStringHelpersWithMatchConfiguration() async throws {
        let regex = try Regex(pattern: #"\d+"#)
        let matchConfiguration = Regex.MatchConfiguration(retryLimitInSearch: 1_000)
        let input = "aa11bb"
        let slice = input[input.index(input.startIndex, offsetBy: 2)...]

        #expect(try regex.firstStringMatch(in: input, matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try regex.firstStringMatch(in: slice, matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try regex.prefixStringMatch(in: input, matchConfiguration: matchConfiguration) == nil)
        #expect(try regex.prefixStringMatch(in: slice, matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try regex.wholeStringMatch(in: "11", matchConfiguration: matchConfiguration)?.substring == "11")
        #expect(try regex.wholeStringMatch(in: slice, matchConfiguration: matchConfiguration) == nil)
        #expect(try regex.firstStringMatch(in: "abc", matchConfiguration: matchConfiguration) == nil)
        #expect(try regex.firstStringMatch(in: "abc"[...], matchConfiguration: matchConfiguration) == nil)
        #expect(try regex.wholeStringMatch(in: "abc"[...]) == nil)
    }

    @Test("Regex.Match maps UTF-16 regex results back to String indices")
    func utf16BackedMatch() async throws {
        let regex = try Regex(patternBytes: Self.utf16LittleEndianBytes("(你好)(世界)"),
                                    encoding: .utf16LittleEndian)
        let input = "prefix 你好世界 suffix"

        let match = try #require(try regex.firstStringMatch(in: input))
        #expect(match.substring == "你好世界")
        #expect(match[1]?.substring == "你好")
        #expect(match[2]?.substring == "世界")
    }
}
