import XCTest

import SwiftOnigTests
import SyntaxTests
import RegionTests
import OnigErrorTests
import RegexTests

var tests = [XCTestCaseEntry]()
tests += SwiftOnigTests.allTests()
tests += SyntaxTests.allTests()
tests += RegionTests.allTests()
tests += OnigErrorTests.allTests()
tests += RegexTests.allTests()
XCTMain(tests)
