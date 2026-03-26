//
//  UTF16Tests.swift
//  
//
//  Created by Guangming Mao on 3/25/26.
//

import Testing
import Foundation
import SwiftOnig

@Suite("UTF-16 & Smart Encoding Tests")
struct UTF16Tests {
    @Test("Raw UTF-16LE search")
    func utf16Search() async throws {
        // "你好" in UTF-16LE
        let utf16Bytes: [UInt16] = [0x4f60, 0x597d] 
        let patternData = utf16Bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        let regex = try await Regex(patternBytes: patternData, encoding: .utf16LittleEndian)
        
        // Target string: "Hello, 你好!" in UTF-16LE
        let target: [UInt16] = [0x0048, 0x0065, 0x006c, 0x006c, 0x006f, 0x002c, 0x0020, 0x4f60, 0x597d, 0x0021]
        let targetData = target.withUnsafeBufferPointer { Data(buffer: $0) }
        
        guard let region = try await regex.firstMatch(in: targetData) else {
            Issue.record("Should have matched")
            return
        }
        
        // Each UTF-16 unit is 2 bytes. "Hello, " is 7 units = 14 bytes.
        #expect(region.range == 14..<18)
    }
    
    @Test("String.UTF16View smart negotiation")
    func stringUTF16View() async throws {
        let input = "Hello, 你好!"
        let utf16Pattern = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
        let regex16 = try await Regex(patternBytes: utf16Pattern, encoding: .utf16LittleEndian)
        
        guard let region = try await regex16.firstMatch(in: input.utf16) else {
            Issue.record("Should have matched")
            return
        }
        
        #expect(region.range == 14..<18)
    }
}
