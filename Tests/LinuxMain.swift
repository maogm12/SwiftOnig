import XCTest

import SwiftOnigTests
import SyntaxTests
import RegionTests

var tests = [XCTestCaseEntry]()
tests += SwiftOnigTests.allTests()
tests += SyntaxTests.allTests()
tests += RegionTests.allTests()
XCTMain(tests)
