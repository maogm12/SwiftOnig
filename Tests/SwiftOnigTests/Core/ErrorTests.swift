//
//  ErrorTests.swift
//  
//
//  Created by Guangming Mao on 4/13/21.
//

import Testing
@testable import SwiftOnig
import OnigurumaC
import Foundation

@Suite("OnigError Tests")
struct OnigErrorTests {
    @Test("Verify regex compilation errors")
    func errorHandling() async throws {
        #expect(throws: OnigError.tooBigNumberForRepeatRange) {
            _ = try Regex(pattern: "a{3,999999999999999999999999999999999999999999}")
        }
        
        do {
            _ = try Regex(pattern: #"(?<$$$>\d+)"#)
            Issue.record("Should have thrown invalidCharInGroupName")
        } catch OnigError.invalidCharInGroupName {
            // Success
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Direct OnigError code mappings remain symmetric")
    func directMappings() {
        let cases: [(OnigInt, OnigError)] = [
            (ONIGERR_MEMORY, .memory),
            (ONIGERR_INVALID_ARGUMENT, .invalidArgument),
            (ONIGERR_END_PATTERN_AT_LEFT_BRACE, .endPatternAtLeftBrace),
            (ONIGERR_INVALID_REPEAT_RANGE_PATTERN, .invalidRepeatRangePattern),
            (ONIGERR_INVALID_CALLOUT_PATTERN, .invalidCalloutPattern),
            (ONIGERR_LIBRARY_IS_NOT_INITIALIZED, .libraryIsNotInitialized),
            (ONIGERR_TOO_MANY_USER_DEFINED_OBJECTS, .tooManyUserDefinedObjects),
        ]

        for (code, error) in cases {
            #expect(OnigError(onigErrorCode: code) == error)
            #expect(error.onigErrorCode == code)
        }
    }

    @Test("Contextual OnigError code mappings preserve details")
    func contextualMappings() {
        let detail = "bad_name"
        let cases: [(OnigInt, OnigError)] = [
            (ONIGERR_INVALID_GROUP_NAME, .invalidGroupName(detail)),
            (ONIGERR_INVALID_CHAR_IN_GROUP_NAME, .invalidCharInGroupName(detail)),
            (ONIGERR_UNDEFINED_NAME_REFERENCE, .undefinedNameReference(detail)),
            (ONIGERR_UNDEFINED_GROUP_REFERENCE, .undefinedGroupReference(detail)),
            (ONIGERR_MULTIPLEX_DEFINED_NAME, .multiplexDefinedName(detail)),
            (ONIGERR_MULTIPLEX_DEFINITION_NAME_CALL, .multiplexDefinitionNameCall(detail)),
            (ONIGERR_INVALID_CHAR_PROPERTY_NAME, .invalidCharPropertyName(detail)),
        ]

        for (code, expected) in cases {
            var info = OnigErrorInfo()
            var bytes = Array(detail.utf8)
            bytes.withUnsafeMutableBufferPointer { pointer in
                info.par = pointer.baseAddress
                info.par_end = pointer.baseAddress?.advanced(by: pointer.count)
                info.enc = Encoding.utf8.rawValue
                #expect(OnigError(onigErrorCode: code, onigErrorInfo: info) == expected)
            }
            #expect(expected.onigErrorCode == code)
        }
    }

    @Test("Synthetic string index mapping failure uses invalid argument code")
    func stringIndexMappingFailureCode() {
        #expect(OnigError.stringIndexMappingFailed.onigErrorCode == ONIGERR_INVALID_ARGUMENT)
    }

    @Test("OnigErrorInfo description decodes bytes using the stored encoding")
    func errorInfoDescription() {
        let message = "こんにちは"
        var bytes = Array(message.utf8)
        var info = OnigErrorInfo()

        bytes.withUnsafeMutableBufferPointer { pointer in
            info.par = pointer.baseAddress
            info.par_end = pointer.baseAddress?.advanced(by: pointer.count)
            info.enc = Encoding.utf8.rawValue
            #expect(info.description == message)
        }
    }

    @Test("OnigErrorInfo description is empty without pointers")
    func errorInfoDescriptionWithoutPointers() {
        let info = OnigErrorInfo()
        #expect(info.description.isEmpty)
    }
}
