//
//  UTF16Tests.swift
//  
//
//  Created by Gavin Mao on 3/25/26.
//

import XCTest
import SwiftOnig

final class UTF16Tests: SwiftOnigTestsBase {
    func testUTF16Search() async throws {
        // "你好" in UTF-16LE
        let utf16Bytes: [UInt16] = [0x4f60, 0x597d] 
        // Use Data to wrap the UInt16 array efficiently
        let patternData = utf16Bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        let regex = try await Regex(patternBytes: patternData, encoding: .utf16LittleEndian)
        
        // Target string: "Hello, 你好!" in UTF-16LE
        let target: [UInt16] = [0x0048, 0x0065, 0x006c, 0x006c, 0x006f, 0x002c, 0x0020, 0x4f60, 0x597d, 0x0021]
        let targetData = target.withUnsafeBufferPointer { Data(buffer: $0) }
        
        guard let region = try await regex.firstMatch(in: targetData) else {
            XCTFail("Should have matched")
            return
        }
        
        // Each UTF-16 unit is 2 bytes. "Hello, " is 7 units = 14 bytes.
        XCTAssertEqual(region.range, 14..<18)
    }
    
    func testStringUTF16View() async throws {
        // Create regex using UTF-8 (default)
        let regex = try await Regex(pattern: "你好")
        let input = "Hello, 你好!"
        
        // Match against UTF-16 view (will involve a copy to contiguous buffer in our implementation)
        // Note: For this to work reliably, the regex and the input should usually have the same encoding.
        // Oniguruma's behavior when searching a UTF-8 regex against a UTF-16 buffer is complex.
        // Let's create a UTF-16 regex for this test.
        let utf16Pattern = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
        let regex16 = try await Regex(patternBytes: utf16Pattern, encoding: .utf16LittleEndian)
        
        guard let region = try await regex16.firstMatch(in: input.utf16) else {
            XCTFail("Should have matched")
            return
        }
        
        XCTAssertEqual(region.range, 14..<18)
    }

    static let allTests = [
        ("testUTF16Search", testUTF16Search),
        ("testStringUTF16View", testStringUTF16View),
    ]
}
