import XCTest

import SwiftOnigTests
import SyntaxTests
import RegionTests
import OnigErrorTests

var tests = [XCTestCaseEntry]()
tests += SwiftOnigTests.allTests()
tests += SyntaxTests.allTests()
tests += RegionTests.allTests()
tests += OnigErrorTests.allTests()
XCTMain(tests)
