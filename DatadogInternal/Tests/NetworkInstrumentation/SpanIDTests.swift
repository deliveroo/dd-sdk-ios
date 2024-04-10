/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import DatadogInternal

class SpanIDTests: XCTestCase {
    func testToHexadecimalStringConversion() {
        XCTAssertEqual(String(SpanID(rawValue: 0), representation: .hexadecimal), "0")
        XCTAssertEqual(String(SpanID(rawValue: 1), representation: .hexadecimal), "1")
        XCTAssertEqual(String(SpanID(rawValue: 15), representation: .hexadecimal), "f")
        XCTAssertEqual(String(SpanID(rawValue: 16), representation: .hexadecimal), "10")
        XCTAssertEqual(String(SpanID(rawValue: 123), representation: .hexadecimal), "7b")
        XCTAssertEqual(String(SpanID(rawValue: 123_456), representation: .hexadecimal), "1e240")
        XCTAssertEqual(String(SpanID(rawValue: .max), representation: .hexadecimal), "ffffffffffffffff")
    }

    func testTo16CharHexadecimalStringConversion() {
        XCTAssertEqual(String(SpanID(rawValue: 0), representation: .hexadecimal16Chars), "0000000000000000")
        XCTAssertEqual(String(SpanID(rawValue: 1), representation: .hexadecimal16Chars), "0000000000000001")
        XCTAssertEqual(String(SpanID(rawValue: 15), representation: .hexadecimal16Chars), "000000000000000f")
        XCTAssertEqual(String(SpanID(rawValue: 16), representation: .hexadecimal16Chars), "0000000000000010")
        XCTAssertEqual(String(SpanID(rawValue: 123), representation: .hexadecimal16Chars), "000000000000007b")
        XCTAssertEqual(String(SpanID(rawValue: 123_456), representation: .hexadecimal16Chars), "000000000001e240")
        XCTAssertEqual(String(SpanID(rawValue: .max), representation: .hexadecimal16Chars), "ffffffffffffffff")
    }

    func testTo32CharHexadecimalStringConversion() {
        XCTAssertEqual(String(SpanID(rawValue: 0), representation: .hexadecimal32Chars), "00000000000000000000000000000000")
        XCTAssertEqual(String(SpanID(rawValue: 1), representation: .hexadecimal32Chars), "00000000000000000000000000000001")
        XCTAssertEqual(String(SpanID(rawValue: 15), representation: .hexadecimal32Chars), "0000000000000000000000000000000f")
        XCTAssertEqual(String(SpanID(rawValue: 16), representation: .hexadecimal32Chars), "00000000000000000000000000000010")
        XCTAssertEqual(String(SpanID(rawValue: 123), representation: .hexadecimal32Chars), "0000000000000000000000000000007b")
        XCTAssertEqual(String(SpanID(rawValue: 123_456), representation: .hexadecimal32Chars), "0000000000000000000000000001e240")
        XCTAssertEqual(String(SpanID(rawValue: .max), representation: .hexadecimal32Chars), "0000000000000000ffffffffffffffff")
    }
    func testToDecimalStringConversion() {
        XCTAssertEqual(String(SpanID(rawValue: 0)), "0")
        XCTAssertEqual(String(SpanID(rawValue: 1)), "1")
        XCTAssertEqual(String(SpanID(rawValue: 15)), "15")
        XCTAssertEqual(String(SpanID(rawValue: 16)), "16")
        XCTAssertEqual(String(SpanID(rawValue: 123)), "123")
        XCTAssertEqual(String(SpanID(rawValue: 123_456)), "123456")
        XCTAssertEqual(String(SpanID(rawValue: .max)), "\(UInt64.max)")
    }

    func testInitializationFromHexadecimal() {
        XCTAssertEqual(SpanID("0", representation: .hexadecimal), 0)
        XCTAssertEqual(SpanID("1", representation: .hexadecimal), 1)
        XCTAssertEqual(SpanID("f", representation: .hexadecimal), 15)
        XCTAssertEqual(SpanID("10", representation: .hexadecimal), 16)
        XCTAssertEqual(SpanID("7b", representation: .hexadecimal), 123)
        XCTAssertEqual(SpanID("1e240", representation: .hexadecimal), 123_456)
        XCTAssertEqual(SpanID("FFFFFFFFFFFFFFFF", representation: .hexadecimal), SpanID(rawValue: .max))
    }

    func testInitializationFromDecimal() {
        XCTAssertEqual(String(SpanID("0")!, representation: .hexadecimal), "0")
        XCTAssertEqual(String(SpanID("1")!, representation: .hexadecimal), "1")
        XCTAssertEqual(String(SpanID("15")!, representation: .hexadecimal), "f")
        XCTAssertEqual(String(SpanID("16")!, representation: .hexadecimal), "10")
        XCTAssertEqual(String(SpanID("123")!, representation: .hexadecimal), "7b")
        XCTAssertEqual(String(SpanID("123456")!, representation: .hexadecimal), "1e240")
        XCTAssertEqual(String(SpanID("\(UInt64.max)")!, representation: .hexadecimal), "ffffffffffffffff")
    }
}
