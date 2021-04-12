//
//  EncodingTests.swift
//  
//
//  Created by Gavin Mao on 4/12/21.
//

import XCTest
@testable import SwiftOnig

final class EncodingTests: SwiftOnigTestsBase {
    func testStringEncoding() {
        let encoding = Encoding.big5

        // 空山新雨後，天氣晚來秋。
        let big5Bytes: [UInt8] = [170, 197, 164, 115, 183, 115, 171, 66, 171, 225, 161, 65, 164, 209, 174, 240, 177, 223, 168, 211, 172, 238, 161, 67]
        XCTAssertEqual(String(bytes: big5Bytes, encoding: encoding.stringEncoding), "空山新雨後，天氣晚來秋。")
        XCTAssertNil(String(bytes: big5Bytes, encoding: .utf8))
    }
    
    static var allTests = [
        ("testStringEncoding", testStringEncoding)
    ]
}
