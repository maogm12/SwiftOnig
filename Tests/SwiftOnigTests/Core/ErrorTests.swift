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
            (ONIGERR_TYPE_BUG, .typeBug),
            (ONIGERR_PARSER_BUG, .parserBug),
            (ONIGERR_STACK_BUG, .stackBug),
            (ONIGERR_UNDEFINED_BYTECODE, .undefinedBytecode),
            (ONIGERR_UNEXPECTED_BYTECODE, .unexpectedBytecode),
            (ONIGERR_MATCH_STACK_LIMIT_OVER, .matchStackLimitOver),
            (ONIGERR_PARSE_DEPTH_LIMIT_OVER, .parseDepthLimitOver),
            (ONIGERR_RETRY_LIMIT_IN_MATCH_OVER, .retryLimitInMatchOver),
            (ONIGERR_RETRY_LIMIT_IN_SEARCH_OVER, .retryLimitInSearchOver),
            (ONIGERR_SUBEXP_CALL_LIMIT_IN_SEARCH_OVER, .subexpCallLimitInSearchOver),
            (ONIGERR_DEFAULT_ENCODING_IS_NOT_SETTED, .defaultEncodingIsNotSetted),
            (ONIGERR_SPECIFIED_ENCODING_CANT_CONVERT_TO_WIDE_CHAR, .specifiedEncodingCantConvertToWideChar),
            (ONIGERR_FAIL_TO_INITIALIZE, .failToInitialize),
            (ONIGERR_INVALID_ARGUMENT, .invalidArgument),
            (ONIGERR_END_PATTERN_AT_LEFT_BRACE, .endPatternAtLeftBrace),
            (ONIGERR_END_PATTERN_AT_LEFT_BRACKET, .endPatternAtLeftBracket),
            (ONIGERR_EMPTY_CHAR_CLASS, .emptyCharClass),
            (ONIGERR_PREMATURE_END_OF_CHAR_CLASS, .prematureEndOfCharClass),
            (ONIGERR_END_PATTERN_AT_ESCAPE, .endPatternAtEscape),
            (ONIGERR_END_PATTERN_AT_META, .endPatternAtMeta),
            (ONIGERR_END_PATTERN_AT_CONTROL, .endPatternAtControl),
            (ONIGERR_META_CODE_SYNTAX, .metaCodeSyntax),
            (ONIGERR_CONTROL_CODE_SYNTAX, .controlCodeSyntax),
            (ONIGERR_CHAR_CLASS_VALUE_AT_END_OF_RANGE, .charClassValueAtEndOfRange),
            (ONIGERR_CHAR_CLASS_VALUE_AT_START_OF_RANGE, .charClassValueAtStartOfRange),
            (ONIGERR_UNMATCHED_RANGE_SPECIFIER_IN_CHAR_CLASS, .unmatchedRangeSpecifierInCharClass),
            (ONIGERR_TARGET_OF_REPEAT_OPERATOR_NOT_SPECIFIED, .targetOfRepeatOperatorNotSpecified),
            (ONIGERR_TARGET_OF_REPEAT_OPERATOR_INVALID, .targetOfRepeatOperatorInvalid),
            (ONIGERR_NESTED_REPEAT_OPERATOR, .nestedRepeatOperator),
            (ONIGERR_UNMATCHED_CLOSE_PARENTHESIS, .unmatchedCloseParenthesis),
            (ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS, .endPatternWithUnmatchedParenthesis),
            (ONIGERR_END_PATTERN_IN_GROUP, .endPatternInGroup),
            (ONIGERR_UNDEFINED_GROUP_OPTION, .undefinedGroupOption),
            (ONIGERR_INVALID_GROUP_OPTION, .invalidGroupOption),
            (ONIGERR_INVALID_POSIX_BRACKET_TYPE, .invalidPosixBracketType),
            (ONIGERR_INVALID_LOOK_BEHIND_PATTERN, .invalidLookBehindPattern),
            (ONIGERR_INVALID_REPEAT_RANGE_PATTERN, .invalidRepeatRangePattern),
            (ONIGERR_TOO_BIG_NUMBER, .tooBigNumber),
            (ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE, .tooBigNumberForRepeatRange),
            (ONIGERR_UPPER_SMALLER_THAN_LOWER_IN_REPEAT_RANGE, .upperSmallerThanLowerInRepeatRange),
            (ONIGERR_EMPTY_RANGE_IN_CHAR_CLASS, .emptyRangeInCharClass),
            (ONIGERR_MISMATCH_CODE_LENGTH_IN_CLASS_RANGE, .mismatchCodeLengthInClassRange),
            (ONIGERR_TOO_MANY_MULTI_BYTE_RANGES, .tooManyMultiByteRanges),
            (ONIGERR_TOO_SHORT_MULTI_BYTE_STRING, .tooShortMultiByteString),
            (ONIGERR_TOO_BIG_BACKREF_NUMBER, .tooBigBackrefNumber),
            (ONIGERR_INVALID_BACKREF, .invalidBackref),
            (ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED, .numberedBackrefOrCallNotAllowed),
            (ONIGERR_TOO_MANY_CAPTURES, .tooManyCaptures),
            (ONIGERR_TOO_LONG_WIDE_CHAR_VALUE, .tooLongWideCharValue),
            (ONIGERR_EMPTY_GROUP_NAME, .emptyGroupName),
            (ONIGERR_UNDEFINED_OPERATOR, .undefinedOperator),
            (ONIGERR_NEVER_ENDING_RECURSION, .neverEndingRecursion),
            (ONIGERR_GROUP_NUMBER_OVER_FOR_CAPTURE_HISTORY, .groupNumberOverForCaptureHistory),
            (ONIGERR_INVALID_IF_ELSE_SYNTAX, .invalidIfElseSyntax),
            (ONIGERR_INVALID_ABSENT_GROUP_PATTERN, .invalidAbsentGroupPattern),
            (ONIGERR_INVALID_ABSENT_GROUP_GENERATOR_PATTERN, .invalidAbsentGroupGeneratorPattern),
            (ONIGERR_INVALID_CALLOUT_PATTERN, .invalidCalloutPattern),
            (ONIGERR_INVALID_CALLOUT_NAME, .invalidCalloutName),
            (ONIGERR_UNDEFINED_CALLOUT_NAME, .undefinedCalloutName),
            (ONIGERR_INVALID_CALLOUT_BODY, .invalidCalloutBody),
            (ONIGERR_INVALID_CALLOUT_TAG_NAME, .invalidCalloutTagName),
            (ONIGERR_INVALID_CALLOUT_ARG, .invalidCalloutArg),
            (ONIGERR_INVALID_CODE_POINT_VALUE, .invalidCodePointValue),
            (ONIGERR_TOO_BIG_WIDE_CHAR_VALUE, .tooBigWideCharValue),
            (ONIGERR_NOT_SUPPORTED_ENCODING_COMBINATION, .notSupportedEncodingCombination),
            (ONIGERR_INVALID_COMBINATION_OF_OPTIONS, .invalidCombinationOfOptions),
            (ONIGERR_LIBRARY_IS_NOT_INITIALIZED, .libraryIsNotInitialized),
            (ONIGERR_TOO_MANY_USER_DEFINED_OBJECTS, .tooManyUserDefinedObjects),
            (ONIGERR_TOO_LONG_PROPERTY_NAME, .tooLongPropertyName),
        ]

        for (code, error) in cases {
            #expect(OnigError(onigErrorCode: code) == error)
            #expect(error.onigErrorCode == code)
        }

        #expect(OnigError.invalidWideCharValue.onigErrorCode == ONIGERR_INVALID_WIDE_CHAR_VALUE)
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
