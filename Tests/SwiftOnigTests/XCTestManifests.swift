import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SwiftOnigTests.allTests),
        testCase(SyntaxTest.allTests),
        testCase(RegionTests.allTests),
        testCase(OnigErrorTests.allTests),
        testCase(RegexTests.allTests),
        testCase(RegexSetTests.allTests),
        testCase(EncodingTests.allTests),
    ]
}
#endif
