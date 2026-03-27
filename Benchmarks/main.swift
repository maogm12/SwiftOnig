//
//  main.swift
//
//
//  Created by Guangming Mao on 3/25/26.
//

import Foundation
import SwiftOnig
import _StringProcessing

private struct BenchmarkCase {
    let name: String
    let iterations: Int
    let body: () async throws -> Void
}

private func benchmark(_ testCase: BenchmarkCase) async throws -> Double {
    let start = DispatchTime.now()
    try await testCase.body()
    let end = DispatchTime.now()
    return Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
}

private func printCaseHeader(_ name: String, iterations: Int) {
    print("")
    print("== \(name) (\(iterations) iterations) ==")
}

private func printResult(engine: String, seconds: Double) {
    let padded = engine.padding(toLength: 22, withPad: " ", startingAt: 0)
    print("\(padded) \(String(format: "%.6f", seconds)) s")
}

private func runSwiftOnigOnly(name: String,
                              iterations: Int,
                              body: @escaping () async throws -> Void) async throws {
    printCaseHeader(name, iterations: iterations)
    let seconds = try await benchmark(BenchmarkCase(name: name, iterations: iterations, body: body))
    printResult(engine: "SwiftOnig", seconds: seconds)
}

private func runComparison(name: String,
                           iterations: Int,
                           swiftOnig: @escaping () async throws -> Void,
                           nsRegularExpression: @escaping () throws -> Void,
                           swiftRegex: @escaping () throws -> Void) async throws {
    printCaseHeader(name, iterations: iterations)

    let onigSeconds = try await benchmark(BenchmarkCase(name: name, iterations: iterations, body: swiftOnig))
    printResult(engine: "SwiftOnig", seconds: onigSeconds)

    let nsSeconds = try await benchmark(BenchmarkCase(name: name, iterations: iterations) {
        try nsRegularExpression()
    })
    printResult(engine: "NSRegularExpression", seconds: nsSeconds)

    let swiftSeconds = try await benchmark(BenchmarkCase(name: name, iterations: iterations) {
        try swiftRegex()
    })
    printResult(engine: "Swift Regex", seconds: swiftSeconds)
}

private func nsRange(for input: String) -> NSRange {
    NSRange(input.startIndex..<input.endIndex, in: input)
}

private let selectedBenchmarkGroup = ProcessInfo.processInfo.environment["BENCH_GROUP"]

private func shouldRun(_ group: String) -> Bool {
    guard let selectedBenchmarkGroup, !selectedBenchmarkGroup.isEmpty else {
        return true
    }
    return selectedBenchmarkGroup == group
}

@available(macOS 13.0, *)
func runBenchmarks() async throws {
    let emailPattern = #"\w+@\w+\.\w+"#
    let emailInput = "Contact us at support@example.com for more info."
    let largeEmailInput = String(repeating: "Some random text with no email. ", count: 1000) + "find@me.com"
    let unicodePattern = #"(你好)(世界)"#
    let unicodeInput = "你好世界"

    try await SwiftOnig.initialize(encodings: [.utf8, .utf16LittleEndian])

    print("--- Regex Engine Benchmarks ---")

    if shouldRun("compile") {
        try await runComparison(
            name: "Compile email pattern",
            iterations: 10_000,
            swiftOnig: {
                for _ in 0..<10_000 {
                    _ = try await SwiftOnig.Regex(pattern: emailPattern)
                }
            },
            nsRegularExpression: {
                for _ in 0..<10_000 {
                    _ = try NSRegularExpression(pattern: emailPattern)
                }
            },
            swiftRegex: {
                for _ in 0..<10_000 {
                    _ = try _StringProcessing.Regex(emailPattern)
                }
            }
        )
    }

    let onigEmail = try await SwiftOnig.Regex(pattern: emailPattern)
    let nsEmail = try NSRegularExpression(pattern: emailPattern)
    let swiftEmail = try _StringProcessing.Regex(emailPattern)

    if shouldRun("short") {
        try await runComparison(
            name: "First match on short input",
            iterations: 1_000_000,
            swiftOnig: {
                for _ in 0..<1_000_000 {
                    _ = try onigEmail.firstMatch(in: emailInput)
                }
            },
            nsRegularExpression: {
                let range = nsRange(for: emailInput)
                for _ in 0..<1_000_000 {
                    _ = nsEmail.firstMatch(in: emailInput, range: range)
                }
            },
            swiftRegex: {
                for _ in 0..<1_000_000 {
                    _ = emailInput.firstMatch(of: swiftEmail)
                }
            }
        )
    }

    if shouldRun("large") {
        try await runComparison(
            name: "First match on large input",
            iterations: 20_000,
            swiftOnig: {
                for _ in 0..<20_000 {
                    _ = try onigEmail.firstMatch(in: largeEmailInput)
                }
            },
            nsRegularExpression: {
                let range = nsRange(for: largeEmailInput)
                for _ in 0..<20_000 {
                    _ = nsEmail.firstMatch(in: largeEmailInput, range: range)
                }
            },
            swiftRegex: {
                for _ in 0..<20_000 {
                    _ = largeEmailInput.firstMatch(of: swiftEmail)
                }
            }
        )
    }

    let onigUnicode = try await SwiftOnig.Regex(pattern: unicodePattern)
    let nsUnicode = try NSRegularExpression(pattern: unicodePattern)
    let swiftUnicode = try _StringProcessing.Regex(unicodePattern)

    if shouldRun("unicode") {
        try await runComparison(
            name: "Unicode capture match",
            iterations: 1_000_000,
            swiftOnig: {
                for _ in 0..<1_000_000 {
                    _ = try onigUnicode.firstMatch(in: unicodeInput)
                }
            },
            nsRegularExpression: {
                let range = nsRange(for: unicodeInput)
                for _ in 0..<1_000_000 {
                    _ = nsUnicode.firstMatch(in: unicodeInput, range: range)
                }
            },
            swiftRegex: {
                for _ in 0..<1_000_000 {
                    _ = unicodeInput.firstMatch(of: swiftUnicode)
                }
            }
        )
    }

    let utf16PatternBytes = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
    let utf16Regex = try await SwiftOnig.Regex(patternBytes: utf16PatternBytes, encoding: .utf16LittleEndian)
    let utf16Input = "Hello, 你好! " + String(repeating: "World", count: 1000)
    let utf16Native = try _StringProcessing.Regex("你好")
    let utf16NS = try NSRegularExpression(pattern: "你好")

    if shouldRun("utf16") {
        try await runComparison(
            name: "UTF-16 smart match from String",
            iterations: 100_000,
            swiftOnig: {
                for _ in 0..<100_000 {
                    _ = try utf16Regex.firstMatch(in: utf16Input)
                }
            },
            nsRegularExpression: {
                let range = nsRange(for: utf16Input)
                for _ in 0..<100_000 {
                    _ = utf16NS.firstMatch(in: utf16Input, range: range)
                }
            },
            swiftRegex: {
                for _ in 0..<100_000 {
                    _ = utf16Input.firstMatch(of: utf16Native)
                }
            }
        )

        try await runComparison(
            name: "UTF-16 oriented match from UTF16View",
            iterations: 100_000,
            swiftOnig: {
                for _ in 0..<100_000 {
                    _ = try utf16Regex.firstMatch(in: utf16Input.utf16)
                }
            },
            nsRegularExpression: {
                let range = nsRange(for: utf16Input)
                for _ in 0..<100_000 {
                    _ = utf16NS.firstMatch(in: utf16Input, range: range)
                }
            },
            swiftRegex: {
                for _ in 0..<100_000 {
                    _ = utf16Input.firstMatch(of: utf16Native)
                }
            }
        )

        try await runSwiftOnigOnly(
            name: "SwiftOnig UTF-16 matchCount from UTF16View",
            iterations: 100_000,
            body: {
                for _ in 0..<100_000 {
                    _ = try utf16Regex.matchCount(in: utf16Input.utf16)
                }
            }
        )
    }

    print("")
    print("-------------------------------")
}

Task {
    do {
        if #available(macOS 13.0, *) {
            try await runBenchmarks()
        } else {
            print("Benchmark failed: Swift Regex benchmarks require macOS 13.0 or newer")
            exit(EXIT_FAILURE)
        }
        exit(EXIT_SUCCESS)
    } catch {
        print("Benchmark failed: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
