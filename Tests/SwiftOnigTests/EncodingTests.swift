//
//  EncodingTests.swift
//  
//
//  Created by Gavin Mao on 4/3/21.
//

import Testing
import SwiftOnig

@Suite("Encoding Tests")
struct EncodingTests {
    @Test("Verify Big5 string encoding mapping")
    func stringEncoding() async throws {
        let encoding = await Encoding.big5

        // 空山新雨後，天氣晚來秋。
        let big5Bytes: [UInt8] = [170, 197, 164, 115, 183, 115, 166, 123, 171, 231, 161, 65, 164, 211, 179, 181, 173, 213, 168, 211, 169, 170, 161, 67]
        #expect(String(bytes: big5Bytes, encoding: encoding.stringEncoding) == "空山新州怎，太陬倘來帚。")
    }
}
