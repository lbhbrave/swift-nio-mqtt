import XCTest

import MQTTDecoderTests

var tests = [XCTestCaseEntry]()
tests += MQTTDecoderTests.allTests()
XCTMain(tests)