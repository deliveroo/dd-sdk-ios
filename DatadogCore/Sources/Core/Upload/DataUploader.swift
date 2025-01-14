/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogInternal
import CommonCrypto

/// A type that performs data uploads.
internal protocol DataUploaderType {
    func upload(events: [Event], context: DatadogContext, previous: DataUploadStatus?) throws -> DataUploadStatus
}

/// Synchronously uploads data to server using `HTTPClient`.
internal final class DataUploader: DataUploaderType {
    /// An unreachable upload status - only meant to satisfy the compiler.
    private static let unreachableUploadStatus = DataUploadStatus(
        needsRetry: false,
        responseCode: nil,
        userDebugDescription: "",
        error: nil,
        attempt: 0
    )

    private let httpClient: HTTPClient
    private let requestBuilder: FeatureRequestBuilder

    init(httpClient: HTTPClient, requestBuilder: FeatureRequestBuilder) {
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
    }

    /// Uploads data synchronously (will block current thread) and returns the upload status.
    /// Uses timeout configured for `HTTPClient`.
    func upload(events: [Event], context: DatadogContext, previous: DataUploadStatus?) throws -> DataUploadStatus {
        let attempt: UInt
        if let previous = previous {
            attempt = previous.attempt + 1
        } else {
            attempt = 0
        }

        let execution: ExecutionContext = .init(previousResponseCode: previous?.responseCode, attempt: attempt)
        let request = try requestBuilder.request(for: events, with: context, execution: execution)

        let requestID = request.value(forHTTPHeaderField: URLRequestBuilder.HTTPHeader.ddRequestIDHeaderField)

        var uploadStatus: DataUploadStatus?

        let semaphore = DispatchSemaphore(value: 0)

        httpClient.send(request: request) { result in
            switch result {
            case .success(let httpResponse):
                uploadStatus = DataUploadStatus(
                    httpResponse: httpResponse,
                    ddRequestID: requestID,
                    attempt: attempt
                )
            case .failure(let error):
                uploadStatus = DataUploadStatus(
                    networkError: error,
                    attempt: attempt
                )
            }

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .distantFuture)

        return uploadStatus ?? DataUploader.unreachableUploadStatus
    }
}
