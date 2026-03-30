import Foundation
import SwiftOnig

private enum TokenStyle: String {
    case keyword = "\u{001B}[38;5;208m"
    case string = "\u{001B}[38;5;114m"
    case number = "\u{001B}[38;5;141m"
    case comment = "\u{001B}[38;5;245m"
    case reset = "\u{001B}[0m"
}

private struct TokenRule {
    let label: String
    let color: TokenStyle
}

private let sample = """
struct BuildReport {
    let title = "SwiftOnig 0.3.0"
    let durationMs = 421
    // Highlight comments, strings, numbers, and keywords.
    func render() -> String { "done" }
}
"""

private let rules: [TokenRule] = [
    TokenRule(label: "keyword", color: .keyword),
    TokenRule(label: "string", color: .string),
    TokenRule(label: "number", color: .number),
    TokenRule(label: "comment", color: .comment),
]

private let patterns = [
    #"\b(?:struct|let|func|return|String)\b"#,
    #""(?:[^"\\]|\\.)*""#,
    #"\b\d+\b"#,
    #"//.*$"#,
]

private func emitHighlighted(source: String, set: RegexSet) throws {
    let utf8Count = source.utf8.count
    var cursor = 0
    var rendered = ""

    while cursor < utf8Count {
        if let match = try set.firstMatch(in: source, of: cursor..<utf8Count, lead: .positionLead),
           match.region.byteRange.lowerBound == cursor,
           let token = match.region.substring(in: source) {
            let rule = rules[match.regexIndex]
            rendered += rule.color.rawValue + token + TokenStyle.reset.rawValue
            cursor = match.region.byteRange.upperBound
        } else {
            let utf8Index = source.utf8.index(source.utf8.startIndex, offsetBy: cursor)
            let nextUTF8Index = source.utf8.index(after: utf8Index)
            let lower = String.Index(utf8Index, within: source)!
            let upper = String.Index(nextUTF8Index, within: source)!
            rendered += String(source[lower..<upper])
            cursor += 1
        }
    }

    print(rendered)
}

do {
    let set = try RegexSet(patterns: patterns)

    print("== Mini Syntax Highlighter ==")
    print("Legend:")
    for rule in rules {
        print("  \(rule.color.rawValue)\(rule.label)\(TokenStyle.reset.rawValue)")
    }
    print("")
    try emitHighlighted(source: sample, set: set)
} catch {
    fputs("Error: \(String(describing: error))\n", stderr)
    exit(EXIT_FAILURE)
}
