import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SwiftOnigTests.allTests),
        testCase(SyntaxTest.allTests),
        testCase(RegionTests.allTests),
    ]
}
#endif
