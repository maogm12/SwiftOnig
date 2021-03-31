import XCTest

import SwiftOnigTests
import SyntaxTests

var tests = [XCTestCaseEntry]()
tests += SwiftOnigTests.allTests()
tests += SyntaxTests.allTests()
XCTMain(tests)
