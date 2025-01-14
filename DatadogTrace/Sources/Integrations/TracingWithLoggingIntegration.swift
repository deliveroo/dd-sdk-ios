/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogInternal

/// Integration between Tracing and Logging Features to allow sending logs for spans (`span.log(fields:timestamp:)`)
internal struct TracingWithLoggingIntegration {
    private struct Constants {
        static let defaultLogMessage = "Span event"
        static let defaultErrorProperty = "Unknown"
    }

    /// Log levels ordered by their severity, with `.debug` being the least severe and
    /// `.critical` being the most severe.
    public enum LogLevel: Int, Codable {
        case debug
        case info
        case notice
        case warn
        case error
        case critical
    }

    struct LogMessage: Encodable {
        static let key = "log"
        /// The Logger name
        let logger: String = "trace"
        /// The Logger service
        let service: String?
        /// The Log date
        let date: Date
        /// The Log message
        let message: String
        /// The Log error
        let error: DDError?
        /// The Log level
        let level: LogLevel
        /// The thread name
        let thread: String
        /// The thread name
        let networkInfoEnabled: Bool
        /// The Log user custom attributes
        let userAttributes: AnyEncodable
        /// The Log internal attributes
        let internalAttributes: SpanCoreContext
    }

    /// `DatadogCore` instance managing this integration.
    weak var core: DatadogCoreProtocol?
    let service: String?
    let networkInfoEnabled: Bool

    init(core: DatadogCoreProtocol, service: String?, networkInfoEnabled: Bool) {
        self.core = core
        self.service = service
        self.networkInfoEnabled = networkInfoEnabled
    }

    // swiftlint:disable function_default_parameter_at_end
    func writeLog(
        withSpanContext spanContext: DDSpanContext,
        message: String? = nil,
        fields: [String: Encodable],
        date: Date,
        else fallback: @escaping () -> Void
    ) {
        guard let core = core else {
            return
        }

        var userAttributes = fields

        // get the log message and optional error kind
        let errorKind: String? = userAttributes.removeValue(forKey: OTLogFields.errorKind)?.dd.decode()
        let message = userAttributes.removeValue(forKey: OTLogFields.message)?.dd.decode() ?? message ?? Constants.defaultLogMessage
        let errorStack: String? = userAttributes.removeValue(forKey: OTLogFields.stack)?.dd.decode()

        // infer the log level
        let isErrorEvent = fields[OTLogFields.event] as? String == "error"
        let hasErrorKind = errorKind != nil
        let level: LogLevel = (isErrorEvent || hasErrorKind) ? .error : .info

        var extractedError: DDError?
        if level == .error {
            extractedError = DDError(
                type: errorKind ?? Constants.defaultErrorProperty,
                message: message,
                stack: errorStack ?? Constants.defaultErrorProperty
            )
        }

        core.send(
            message: .baggage(
                key: LogMessage.key,
                value: LogMessage(
                    service: service,
                    date: date,
                    message: message,
                    error: extractedError,
                    level: level,
                    thread: Thread.current.dd.name,
                    networkInfoEnabled: networkInfoEnabled,
                    userAttributes: AnyEncodable(userAttributes),
                    internalAttributes: SpanCoreContext(
                        traceID: String(spanContext.traceID, representation: .hexadecimal),
                        spanID: String(spanContext.spanID, representation: .hexadecimal)
                    )
                )
            ),
            else: fallback
        )
    }
    // swiftlint:enable function_default_parameter_at_end
}
