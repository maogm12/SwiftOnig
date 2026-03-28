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
        let regex = try await Regex(pattern: #"(?<word>\w+)-(?<digits>\d+)"#)
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
        let regex = try await Regex(pattern: #"\d+"#)
        let input = "aa11bb22"
        let slice = input[input.index(input.startIndex, offsetBy: 2)...]

        let match = try #require(try regex.firstStringMatch(in: slice))
        #expect(match.substring == "11")
        #expect(match.range.lowerBound == slice.startIndex)
    }

    @Test("Prefix and whole string match helpers")
    func prefixAndWholeStringMatch() async throws {
        let regex = try await Regex(pattern: #"\d+"#)

        #expect(try regex.prefixStringMatch(in: "123abc")?.substring == "123")
        #expect(try regex.prefixStringMatch(in: "abc123") == nil)
        #expect(try regex.wholeStringMatch(in: "123")?.substring == "123")
        #expect(try regex.wholeStringMatch(in: "123abc") == nil)
    }

    @Test("String and Substring expose native-style match APIs")
    func stringNativeEntryPoints() async throws {
        let regex = try await Regex(pattern: #"(?<word>\w+)-(?<digits>\d+)"#)
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
        let regex = try await Regex(pattern: #"\d+"#)
        let missRegex = try await Regex(pattern: #"xyz"#)
        let input = "prefix 123 suffix"
        let slice = input[input.index(input.startIndex, offsetBy: 7)...]

        #expect(try input.contains(regex))
        #expect(try !input.contains(missRegex))
        #expect(try slice.contains(regex))
        #expect(try !"prefix".contains(regex))
    }

    @Test("String and Substring expose regex matches and ranges")
    func stringNativeMatchesAndRanges() async throws {
        let regex = try await Regex(pattern: #"(?<digits>\d+)"#)
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
        let regex = try await Regex(pattern: #"\d+"#)

        #expect(try "aa11bb22cc333".replacing(regex, with: "#") == "aa#bb#cc#")
        #expect(try "prefix".replacing(regex, with: "#") == "prefix")
        #expect(try "你好123世界45".replacing(regex, with: "-") == "你好-世界-")
    }

    @Test("Regex.Match maps UTF-16 regex results back to String indices")
    func utf16BackedMatch() async throws {
        let regex = try await Regex(patternBytes: Self.utf16LittleEndianBytes("(你好)(世界)"),
                                    encoding: .utf16LittleEndian)
        let input = "prefix 你好世界 suffix"

        let match = try #require(try regex.firstStringMatch(in: input))
        #expect(match.substring == "你好世界")
        #expect(match[1]?.substring == "你好")
        #expect(match[2]?.substring == "世界")
    }
}
