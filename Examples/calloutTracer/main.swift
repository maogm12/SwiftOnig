import Foundation
import SwiftOnig

private final class EventBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values = [String]()

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }
}

private func describe(_ context: OnigurumaCalloutContext) -> String {
    let captures = context.captureByteRanges
        .enumerated()
        .map { index, range in
            "\(index)=\(range.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "nil")"
        }
        .joined(separator: ", ")

    return "[\(context.phase)] content=\(context.contents ?? "<none>") current=\(context.currentByteOffset) start=\(context.startByteOffset) upper=\(context.searchByteRangeUpperBound) captures=[\(captures)]"
}

private func runNamedCalloutDemo() throws {
    print("== Named Callout Demo ==")
    print("Pattern: \\A(*trace)ID-(\\d+)\\z")
    print("Input:   ID-2048")

    Oniguruma.uninitialize()

    let namedEvents = EventBox()
    try Oniguruma.registerCallout(named: "trace") { context in
        namedEvents.append(describe(context))
        return .continue
    }

    let regex = try Regex(pattern: #"\A(*trace)ID-(\d+)\z"#)
    guard let match = try "ID-2048".firstMatch(of: regex) else {
        fatalError("Expected named callout demo to match")
    }

    for event in namedEvents.values {
        print(event)
    }
    print("Whole match: \(match.substring)")
    print("Digits: \(match[1]?.substring ?? "<missing>")")
    print("")
}

private func runBacktrackingDemo() throws {
    print("== Backtracking Demo ==")
    print("Pattern: \\A(?:(?{R}X)a)?a\\z")
    print("Input:   a")

    let matchConfiguration = Regex.MatchConfiguration(
        progressHandler: { context in
            print(describe(context))
            return .continue
        },
        retractionHandler: { context in
            print(describe(context))
            return .continue
        }
    )

    let regex = try Regex(pattern: #"\A(?:(?{R}X)a)?a\z"#)
    let matched = try "a".firstMatch(of: regex, matchConfiguration: matchConfiguration) != nil
    print("Matched: \(matched)")
}

do {
    try runNamedCalloutDemo()
    try runBacktrackingDemo()
} catch {
    fputs("Error: \(String(describing: error))\n", stderr)
    exit(EXIT_FAILURE)
}
