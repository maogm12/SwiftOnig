//
//  EncodingTests.swift
//  
//
//  Created by Guangming Mao on 4/3/21.
//

import Testing
import SwiftOnig
import Foundation

@Suite("Encoding Tests")
struct EncodingTests {
    @Test("Verify Big5 string encoding mapping")
    func stringEncoding() async throws {
        // "空山新雨後，天氣晚來秋。" in Big5
        let big5Bytes: [UInt8] = [
            0xAA, 0xC5, // 空
            0xA4, 0x73, // 山
            0xB7, 0x73, // 新
            0xAB, 0x42, // 雨
            0xAB, 0xE1, // 後
            0xA1, 0x41, // ，
            0xA4, 0xD1, // 天
            0xAE, 0xF0, // 氣
            0xB1, 0xDF, // 晚
            0xA8, 0xD3, // 來
            0xAC, 0xEE, // 秋
            0xA1, 0x43  // 。
        ]

        let encoding = Encoding.big5
        let decoded = String(bytes: big5Bytes, encoding: encoding.stringEncoding)
        #expect(decoded == "空山新雨後，天氣晚來秋。")
    }

    @Test("Null-terminated byte helpers stop at embedded null")
    func nullTerminatedHelpers() async throws {
        let bytes: [UInt8] = [0x41, 0x00, 0x42, 0x43]
        let encoding = Encoding.utf8

        #expect(encoding.characterCount(in: bytes) == 4)
        #expect(encoding.nullTerminatedCharacterCount(in: bytes) == 1)
        #expect(encoding.nullTerminatedByteCount(in: bytes) == 1)
        #expect(encoding.previousCharacterHead(in: bytes, before: 0) == nil)
    }

    @Test("Built-in encoding presets are synchronously accessible")
    func builtInPresetsAreSync() {
        #expect(Encoding.utf8.stringEncoding == .utf8)
        #expect(Encoding.big5.stringEncoding != .utf8)
    }

    @Test("All built-in encoding presets expose stable descriptions")
    func allBuiltInPresets() {
        let encodings: [Encoding] = [
            .ascii,
            .iso8859Part1,
            .iso8859Part2,
            .iso8859Part3,
            .iso8859Part4,
            .iso8859Part5,
            .iso8859Part6,
            .iso8859Part7,
            .iso8859Part8,
            .iso8859Part9,
            .iso8859Part10,
            .iso8859Part11,
            .iso8859Part13,
            .iso8859Part14,
            .iso8859Part15,
            .iso8859Part16,
            .utf8,
            .utf16BigEndian,
            .utf16LittleEndian,
            .utf32BigEndian,
            .utf32LittleEndian,
            .eucJP,
            .eucTW,
            .eucKR,
            .eucCN,
            .shiftJIS,
            .koi8r,
            .cp1251,
            .big5,
            .gb18030,
        ]

        #expect(Set(encodings.map(\.description)).count > 10)
        #expect(encodings.allSatisfy { !$0.description.isEmpty })
    }
}
