import XCTest

import SwiftOnigTests
import SyntaxTests
import RegionTests
import OnigErrorTests
import RegexTests
import RegexSetTests
import EncodingTests

var tests = [XCTestCaseEntry]()
tests += SwiftOnigTests.allTests()
tests += SyntaxTests.allTests()
tests += RegionTests.allTests()
tests += OnigErrorTests.allTests()
tests += RegexTests.allTests()
tests += RegexSetTests.allTests()
tests += EncodingTests.allTests()
XCTMain(tests)
