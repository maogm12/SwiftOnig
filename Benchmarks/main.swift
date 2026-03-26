//
//  main.swift
//  
//
//  Created by Guangming Mao on 3/25/26.
//

import Foundation
import SwiftOnig

@OnigurumaActor
func benchmark(name: String, block: () async throws -> Void) async throws {
    let start = DispatchTime.now()
    try await block()
    let end = DispatchTime.now()
    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000_000
    print("\(name): \(timeInterval) seconds")
}

@OnigurumaActor
func runBenchmarks() async throws {
    print("--- SwiftOnig Benchmarks ---")
    
    // 1. Initialization
    try await benchmark(name: "Initialization (UTF-8)") {
        try await SwiftOnig.initialize(encodings: [.utf8])
    }
    
    // 2. Regex Compilation
    let pattern = #"\w+@\w+\.\w+"#
    try await benchmark(name: "Compilation (1000 times)") {
        for _ in 0..<1000 {
            _ = try await Regex(pattern: pattern)
        }
    }
    
    // 3. Simple Match
    let regex = try await Regex(pattern: pattern)
    let input = "Contact us at support@example.com for more info."
    try await benchmark(name: "Match (100,000 times)") {
        for _ in 0..<100_000 {
            _ = try regex.firstMatch(in: input)
        }
    }
    
    // 4. Large Input Match
    let largeInput = String(repeating: "Some random text with no email. ", count: 1000) + "find@me.com"
    try await benchmark(name: "Large Input Match (100 times)") {
        for _ in 0..<100 {
            _ = try regex.firstMatch(in: largeInput)
        }
    }
    
    // 5. UTF-16 Match (Smart Negotiation)
    let utf16PatternBytes = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
    let utf16Regex = try await Regex(patternBytes: utf16PatternBytes, encoding: .utf16LittleEndian)
    let utf16Input = "Hello, 你好! " + String(repeating: "World", count: 1000)
    try await benchmark(name: "UTF-16 Smart Match (10,000 times)") {
        for _ in 0..<10_000 {
            _ = try await utf16Regex.firstMatch(in: utf16Input.utf16)
        }
    }
    
    print("----------------------------")
}

Task {
    do {
        try await runBenchmarks()
        exit(EXIT_SUCCESS)
    } catch {
        print("Benchmark failed: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
