/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
@testable import DatadogInternal

private class AsyncOperator: DispatchContinuation {
    private(set) static var referenceCount: Int = 0

    let queue: DispatchQueue
    let delay: TimeInterval
    let expectation: XCTestExpectation?

    init(
        label: String,
        delay: TimeInterval = 0.1,
        expectation: XCTestExpectation? = nil
    ) {
        self.queue = DispatchQueue(label: label)
        self.delay = delay
        self.expectation = expectation
        AsyncOperator.referenceCount += 1
    }

    deinit {
        AsyncOperator.referenceCount -= 1
    }

    func execute() {
        queue.async {
            // retain self
            Thread.sleep(forTimeInterval: self.delay)
        }
    }

    func notify(_ continuation: @escaping () -> Void) {
        let expectation = self.expectation
        queue.notify {
            expectation?.fulfill()
            continuation()
        }
    }
}

class DispatchContinuationTests: XCTestCase {
    func testSuccessfulWait() {
        autoreleasepool {
            // Given
            let operation = AsyncOperator(label: "flush.test", delay: 0.1)

            // When
            operation.execute()
            let result = operation.waitDispatchContinuation(timeout: 0.2)

            // Then
            XCTAssertEqual(result, .success)
        }
    }

    func testTimeout() {
        autoreleasepool {
            // Given
            let operation = AsyncOperator(label: "flush.test", delay: 0.2)

            // When
            operation.execute()
            let result = operation.waitDispatchContinuation(timeout: 0.1)

            // Then
            XCTAssertEqual(result, .timedOut)
        }
    }

    func testSingleOperations() {
        autoreleasepool {
            // Given
            let operation = AsyncOperator(label: "flush.test", delay: .mockRandom(min: 0.1, max: 0.5))

            // When
            operation.waitDispatchContinuation()

            // Then
            XCTAssertEqual(AsyncOperator.referenceCount, 1)
        }

        // Then
        XCTAssertEqual(AsyncOperator.referenceCount, 0)
    }

    func testSequenceOfSimultaneousOperations() {
        let operationCount: Int = 100
        let expectations = (0..<operationCount).map { expectation(description: "expect \($0) task") }

        autoreleasepool {
            // Given
            let operations = expectations.map {
                AsyncOperator(
                    label: $0.expectationDescription,
                    delay: .mockRandom(min: 0, max: 0.5),
                    expectation: $0
                )
            }
            // When
            operations.forEach { $0.execute() }
            DispatchContinuationSequence(group: operations).waitDispatchContinuation()

            // Then
            XCTAssertEqual(AsyncOperator.referenceCount, operationCount)
        }

        // Then
        XCTAssertEqual(AsyncOperator.referenceCount, 0)
        wait(for: expectations, timeout: 0, enforceOrder: false)
    }

    func testChainOfOperations() {
        let operationCount: Int = 100
        let expectations = (0..<operationCount).map { expectation(description: "expect \($0) task") }

        autoreleasepool {
            // Given
            let operations = expectations.map {
                AsyncOperator(
                    label: $0.expectationDescription,
                    delay: .mockRandom(min: 0, max: 0.5),
                    expectation: $0
                )
            }

            // When
            operations.forEach { $0.execute() }
            operations.reduce(DispatchContinuationSequence()) { chain, next in
                chain.then(next)
            }
            .waitDispatchContinuation()

            // Then
            XCTAssertEqual(AsyncOperator.referenceCount, operationCount)
        }

        // Then
        XCTAssertEqual(AsyncOperator.referenceCount, 0)

        // expect order of continuation
        wait(for: expectations, timeout: 0, enforceOrder: true)
    }
}
