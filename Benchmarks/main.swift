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
    let group: String
    let name: String
    let iterations: Int
    let body: () async throws -> Void
}

private struct BenchmarkStats {
    let samples: [Double]

    var min: Double { samples.min() ?? 0 }
    var max: Double { samples.max() ?? 0 }
    var median: Double {
        let sorted = samples.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

private func benchmark(_ testCase: BenchmarkCase) async throws -> Double {
    let start = DispatchTime.now()
    try await testCase.body()
    let end = DispatchTime.now()
    return Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
}

private func benchmark(_ testCase: BenchmarkCase, warmupRuns: Int, measuredRuns: Int) async throws -> BenchmarkStats {
    precondition(measuredRuns > 0, "measuredRuns must be positive")

    for _ in 0..<warmupRuns {
        _ = try await benchmark(testCase)
    }

    var samples = [Double]()
    samples.reserveCapacity(measuredRuns)
    for _ in 0..<measuredRuns {
        samples.append(try await benchmark(testCase))
    }
    return BenchmarkStats(samples: samples)
}

private func printCaseHeader(_ name: String, iterations: Int) {
    print("")
    print("== \(name) (\(iterations) iterations) ==")
}

private func printResult(engine: String, stats: BenchmarkStats) {
    let padded = engine.padding(toLength: 22, withPad: " ", startingAt: 0)
    print(
        "\(padded) median \(String(format: "%.6f", stats.median)) s  " +
        "min \(String(format: "%.6f", stats.min)) s  " +
        "max \(String(format: "%.6f", stats.max)) s"
    )
}

private func makeCase(group: String,
                      name: String,
                      iterations: Int,
                      body: @escaping () async throws -> Void) -> BenchmarkCase {
    BenchmarkCase(group: group, name: name, iterations: iterations, body: body)
}

private let benchmarkWarmupRuns = max(0, Int(ProcessInfo.processInfo.environment["BENCH_WARMUP"] ?? "") ?? 1)
private let benchmarkMeasuredRuns = max(1, Int(ProcessInfo.processInfo.environment["BENCH_SAMPLES"] ?? "") ?? 5)
private let selectedBenchmarkGroup = ProcessInfo.processInfo.environment["BENCH_GROUP"]
private let selectedBenchmarkCase = ProcessInfo.processInfo.environment["BENCH_CASE"]

private func shouldRun(group: String, name: String) -> Bool {
    if let selectedBenchmarkGroup, !selectedBenchmarkGroup.isEmpty, selectedBenchmarkGroup != group {
        return false
    }
    if let selectedBenchmarkCase, !selectedBenchmarkCase.isEmpty, selectedBenchmarkCase != name {
        return false
    }
    return true
}

private func runSwiftOnigOnly(_ testCase: BenchmarkCase) async throws {
    guard shouldRun(group: testCase.group, name: testCase.name) else {
        return
    }

    printCaseHeader(testCase.name, iterations: testCase.iterations)
    let stats = try await benchmark(testCase, warmupRuns: benchmarkWarmupRuns, measuredRuns: benchmarkMeasuredRuns)
    printResult(engine: "SwiftOnig", stats: stats)
}

private func runComparison(_ testCase: BenchmarkCase,
                           swiftOnig: @escaping () async throws -> Void,
                           nsRegularExpression: @escaping () throws -> Void,
                           swiftRegex: @escaping () throws -> Void) async throws {
    guard shouldRun(group: testCase.group, name: testCase.name) else {
        return
    }

    printCaseHeader(testCase.name, iterations: testCase.iterations)

    let onigStats = try await benchmark(
        makeCase(group: testCase.group, name: testCase.name, iterations: testCase.iterations, body: swiftOnig),
        warmupRuns: benchmarkWarmupRuns,
        measuredRuns: benchmarkMeasuredRuns
    )
    printResult(engine: "SwiftOnig", stats: onigStats)

    let nsStats = try await benchmark(
        makeCase(group: testCase.group, name: testCase.name, iterations: testCase.iterations) {
            try nsRegularExpression()
        },
        warmupRuns: benchmarkWarmupRuns,
        measuredRuns: benchmarkMeasuredRuns
    )
    printResult(engine: "NSRegularExpression", stats: nsStats)

    let swiftStats = try await benchmark(
        makeCase(group: testCase.group, name: testCase.name, iterations: testCase.iterations) {
            try swiftRegex()
        },
        warmupRuns: benchmarkWarmupRuns,
        measuredRuns: benchmarkMeasuredRuns
    )
    printResult(engine: "Swift Regex", stats: swiftStats)
}

private func nsRange(for input: String) -> NSRange {
    NSRange(input.startIndex..<input.endIndex, in: input)
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
    print("Warmup runs: \(benchmarkWarmupRuns)")
    print("Measured samples: \(benchmarkMeasuredRuns)")
    if let selectedBenchmarkGroup, !selectedBenchmarkGroup.isEmpty {
        print("Selected group: \(selectedBenchmarkGroup)")
    }
    if let selectedBenchmarkCase, !selectedBenchmarkCase.isEmpty {
        print("Selected case: \(selectedBenchmarkCase)")
    }

    try await runComparison(
        makeCase(group: "compile",
                 name: "Compile email pattern",
                 iterations: 10_000) {
            for _ in 0..<10_000 {
                _ = try await SwiftOnig.Regex(pattern: emailPattern)
            }
        },
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

    let onigEmail = try await SwiftOnig.Regex(pattern: emailPattern)
    let nsEmail = try NSRegularExpression(pattern: emailPattern)
    let swiftEmail = try _StringProcessing.Regex(emailPattern)

    try await runComparison(
        makeCase(group: "short",
                 name: "First match on short input",
                 iterations: 1_000_000) {
            for _ in 0..<1_000_000 {
                _ = try emailInput.firstMatch(of: onigEmail)
            }
        },
        swiftOnig: {
            for _ in 0..<1_000_000 {
                _ = try emailInput.firstMatch(of: onigEmail)
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

    try await runComparison(
        makeCase(group: "large",
                 name: "First match on large input",
                 iterations: 20_000) {
            for _ in 0..<20_000 {
                _ = try largeEmailInput.firstMatch(of: onigEmail)
            }
        },
        swiftOnig: {
            for _ in 0..<20_000 {
                _ = try largeEmailInput.firstMatch(of: onigEmail)
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

    let onigUnicode = try await SwiftOnig.Regex(pattern: unicodePattern)
    let nsUnicode = try NSRegularExpression(pattern: unicodePattern)
    let swiftUnicode = try _StringProcessing.Regex(unicodePattern)

    try await runComparison(
        makeCase(group: "unicode",
                 name: "Unicode capture match",
                 iterations: 1_000_000) {
            for _ in 0..<1_000_000 {
                _ = try unicodeInput.firstMatch(of: onigUnicode)
            }
        },
        swiftOnig: {
            for _ in 0..<1_000_000 {
                _ = try unicodeInput.firstMatch(of: onigUnicode)
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

    let utf16PatternBytes = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
    let utf16Regex = try await SwiftOnig.Regex(patternBytes: utf16PatternBytes, encoding: .utf16LittleEndian)
    let utf16AnchoredInput = "你好! " + String(repeating: "World", count: 1000)
    let utf16Input = "Hello, 你好! " + String(repeating: "World", count: 1000)
    let utf16PreparedInput = UTF16CodeUnitBuffer(utf16Input.utf16)
    let utf16MissInput = String(repeating: "World", count: 1002)
    let utf16Native = try _StringProcessing.Regex("你好")
    let utf16NS = try NSRegularExpression(pattern: "你好")

    try await runComparison(
        makeCase(group: "utf16",
                 name: "UTF-16 smart match from String",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Input.firstMatch(of: utf16Regex)
            }
        },
        swiftOnig: {
            for _ in 0..<100_000 {
                _ = try utf16Input.firstMatch(of: utf16Regex)
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
        makeCase(group: "utf16",
                 name: "UTF-16 oriented match from UTF16View",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Regex.firstMatch(in: utf16Input.utf16)
            }
        },
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
        makeCase(group: "utf16",
                 name: "SwiftOnig UTF-16 explicit contiguous match from UTF16CodeUnitBuffer",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Regex.firstMatch(in: utf16PreparedInput)
            }
        }
    )

    try await runSwiftOnigOnly(
        makeCase(group: "utf16",
                 name: "SwiftOnig UTF-16 anchored firstMatch from UTF16View",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Regex.firstMatch(in: utf16AnchoredInput.utf16)
            }
        }
    )

    try await runSwiftOnigOnly(
        makeCase(group: "utf16",
                name: "SwiftOnig UTF-16 anchored matchedByteCount from UTF16View",
                iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Regex.matchedByteCount(in: utf16AnchoredInput.utf16)
            }
        }
    )

    try await runSwiftOnigOnly(
        makeCase(group: "utf16",
                 name: "SwiftOnig UTF-16 matchedByteCount from UTF16View",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Regex.matchedByteCount(in: utf16Input.utf16)
            }
        }
    )

    try await runSwiftOnigOnly(
        makeCase(group: "utf16",
                 name: "SwiftOnig UTF-16 mismatch from String",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16MissInput.firstMatch(of: utf16Regex)
            }
        }
    )

    try await runSwiftOnigOnly(
        makeCase(group: "utf16",
                 name: "SwiftOnig UTF-16 mismatch from UTF16View",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Regex.firstMatch(in: utf16MissInput.utf16)
            }
        }
    )

    try await runSwiftOnigOnly(
        makeCase(group: "utf16",
                 name: "SwiftOnig UTF-16 wholeMatch from String",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                _ = try utf16Input.wholeMatch(of: utf16Regex)
            }
        }
    )

    try await runSwiftOnigOnly(
        makeCase(group: "utf16",
                name: "SwiftOnig UTF-16 firstMatch plus region.decodedString()",
                 iterations: 100_000) {
            for _ in 0..<100_000 {
                let match = try utf16Input.firstMatch(of: utf16Regex)
                _ = match?.substring
            }
        }
    )

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
