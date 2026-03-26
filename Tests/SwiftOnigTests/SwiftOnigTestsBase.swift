//
//  SwiftOnigTestsBase.swift
//  
//
//  Created by Gavin Mao on 4/12/21.
//

import XCTest
import SwiftOnig

@OnigurumaActor
class SwiftOnigTestsBase: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // SwiftOnig now handles initialization automatically on first use.
    }
    
    override func tearDown() async throws {
        await uninitialize()
        try await super.tearDown()
    }
}

@OnigurumaActor
func XCTAssertThrowsSpecific<E: Error & Equatable>(_ expression: @autoclosure () async throws -> Any?,
                                                  _ expectedError: E,
                                                  _ message: String = "",
                                                  file: StaticString = #filePath,
                                                  line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("Expression did not throw", file: file, line: line)
    } catch let error as E {
        XCTAssertEqual(error, expectedError, message, file: file, line: line)
    } catch {
        XCTFail("Expression threw \(error) instead of \(expectedError)", file: file, line: line)
    }
}
