/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogInternal

/// A type managing RUM information necessary for building context of fatal errors such as Crashes or Fatal App Hangs.
internal protocol FatalErrorContextNotifying: AnyObject {
    /// The state of the current RUM session.
    /// Can be `nil` if no session was yet started. Never gets `nil` after starting first session.
    var sessionState: RUMSessionState? { set get }
    /// The active RUM view in current session.
    /// Can be `nil` if no view is yet started. Will become `nil` if view was stopped without starting the new one.
    var view: RUMViewEvent? { set get }
    /// The current set of RUM attributes.
    /// It gets updated with global attributes being added or removed in `RUMMonitor`.
    var globalAttributes: [String: Encodable] { set get }
}

/// Manages RUM information necessary for building context of fatal errors such as Crashes or Fatal App Hangs.
/// It tracks value changes and notifies updates on message bus.
internal final class FatalErrorContextNotifier: FatalErrorContextNotifying {
    /// Message bus interface to send context updates to Crash Reporting.
    private let messageBus: MessageSending

    init(messageBus: MessageSending) {
        self.messageBus = messageBus
    }

    /// The state of the current RUM session.
    /// Can be `nil` if no session was yet started. Never gets `nil` after starting first session.
    @ReadWriteLock
    var sessionState: RUMSessionState? {
        didSet {
            if let sessionState = sessionState {
                messageBus.send(message: .baggage(key: RUMBaggageKeys.sessionState, value: sessionState))
            }
        }
    }

    /// The active RUM view in current session.
    /// Can be `nil` if no view is yet started. Will become `nil` if view was stopped without starting the new one.
    @ReadWriteLock
    var view: RUMViewEvent? {
        didSet {
            if let lastRUMView = view {
                messageBus.send(message: .baggage(key: RUMBaggageKeys.viewEvent, value: lastRUMView))
            } else {
                messageBus.send(message: .baggage(key: RUMBaggageKeys.viewReset, value: true))
            }
        }
    }

    @ReadWriteLock
    var globalAttributes: [String: Encodable] = [:] {
        didSet {
            messageBus.send(
                message: .baggage(
                    key: RUMBaggageKeys.attributes,
                    value: GlobalRUMAttributes(attributes: globalAttributes)
                )
            )
        }
    }
}
