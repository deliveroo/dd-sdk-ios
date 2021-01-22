/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class DatadogTests: XCTestCase {
    private var printFunction: PrintFunctionMock! // swiftlint:disable:this implicitly_unwrapped_optional
    private var defaultBuilder: Datadog.Configuration.Builder {
        Datadog.Configuration.builderUsing(clientToken: "abc-123", environment: "tests")
    }
    private var rumBuilder: Datadog.Configuration.Builder {
        Datadog.Configuration.builderUsing(rumApplicationID: "rum-123", clientToken: "abc-123", environment: "tests")
    }

    override func setUp() {
        super.setUp()
        XCTAssertNil(Datadog.instance)
        printFunction = PrintFunctionMock()
        consolePrint = printFunction.print
    }

    override func tearDown() {
        consolePrint = { print($0) }
        printFunction = nil
        XCTAssertNil(Datadog.instance)
        super.tearDown()
    }

    // MARK: - Initializing with different configurations

    func testGivenDefaultConfiguration_itCanBeInitialized() throws {
        Datadog.initialize(
            appContext: .mockAny(),
            trackingConsent: .mockRandom(),
            configuration: defaultBuilder.build()
        )
        XCTAssertNotNil(Datadog.instance)
        try Datadog.deinitializeOrThrow()
    }

    func testGivenDefaultRUMConfiguration_itCanBeInitialized() throws {
        Datadog.initialize(
            appContext: .mockAny(),
            trackingConsent: .mockRandom(),
            configuration: rumBuilder.build()
        )
        XCTAssertNotNil(Datadog.instance)
        try Datadog.deinitializeOrThrow()
    }

    func testGivenInvalidConfiguration_itPrintsError() throws {
        let invalidConiguration = Datadog.Configuration
            .builderUsing(clientToken: "", environment: "tests")
            .build()

        Datadog.initialize(
            appContext: .mockAny(),
            trackingConsent: .mockRandom(),
            configuration: invalidConiguration
        )

        XCTAssertEqual(
            printFunction.printedMessage,
            "🔥 Datadog SDK usage error: `clientToken` cannot be empty."
        )
        XCTAssertNil(Datadog.instance)
    }

    func testGivenValidConfiguration_whenInitializedMoreThanOnce_itPrintsError() throws {
        Datadog.initialize(
            appContext: .mockAny(),
            trackingConsent: .mockRandom(),
            configuration: defaultBuilder.build()
        )
        Datadog.initialize(
            appContext: .mockAny(),
            trackingConsent: .mockRandom(),
            configuration: rumBuilder.build()
        )

        XCTAssertEqual(
            printFunction.printedMessage,
            "🔥 Datadog SDK usage error: SDK is already initialized."
        )

        try Datadog.deinitializeOrThrow()
    }

    // MARK: - Toggling features

    func testEnablingAndDisablingFeatures() throws {
        func verify(configuration: Datadog.Configuration, verificationBlock: () -> Void) throws {
            Datadog.initialize(
                appContext: .mockAny(),
                trackingConsent: .mockRandom(),
                configuration: configuration
            )
            verificationBlock()

            RUMAutoInstrumentation.instance?.views?.swizzler.unswizzle()
            URLSessionAutoInstrumentation.instance?.swizzler.unswizzle()
            try Datadog.deinitializeOrThrow()
        }

        defer {
            RUMAutoInstrumentation.instance?.views?.swizzler.unswizzle()
            URLSessionAutoInstrumentation.instance?.swizzler.unswizzle()
        }

        try verify(configuration: defaultBuilder.build()) {
            // verify features:
            XCTAssertTrue(LoggingFeature.isEnabled)
            XCTAssertTrue(TracingFeature.isEnabled)
            XCTAssertFalse(RUMFeature.isEnabled, "When using `defaultBuilder` RUM feature should be disabled by default")
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
            // verify integrations:
            XCTAssertNotNil(TracingFeature.instance?.loggingFeatureAdapter)
        }
        try verify(configuration: rumBuilder.build()) {
            // verify features:
            XCTAssertTrue(LoggingFeature.isEnabled)
            XCTAssertTrue(TracingFeature.isEnabled)
            XCTAssertTrue(RUMFeature.isEnabled, "When using `rumBuilder` RUM feature should be enabled by default")
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
            // verify integrations:
            XCTAssertNotNil(TracingFeature.instance?.loggingFeatureAdapter)
        }

        try verify(configuration: defaultBuilder.enableLogging(false).build()) {
            // verify features:
            XCTAssertFalse(LoggingFeature.isEnabled)
            XCTAssertTrue(TracingFeature.isEnabled)
            XCTAssertFalse(RUMFeature.isEnabled, "When using `defaultBuilder` RUM feature should be disabled by default")
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
            // verify integrations:
            XCTAssertNil(TracingFeature.instance?.loggingFeatureAdapter)
        }
        try verify(configuration: rumBuilder.enableLogging(false).build()) {
            // verify features:
            XCTAssertFalse(LoggingFeature.isEnabled)
            XCTAssertTrue(TracingFeature.isEnabled)
            XCTAssertTrue(RUMFeature.isEnabled, "When using `rumBuilder` RUM feature should be enabled by default")
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
            // verify integrations:
            XCTAssertNil(TracingFeature.instance?.loggingFeatureAdapter)
        }

        try verify(configuration: defaultBuilder.enableTracing(false).build()) {
            // verify features:
            XCTAssertTrue(LoggingFeature.isEnabled)
            XCTAssertFalse(TracingFeature.isEnabled)
            XCTAssertFalse(RUMFeature.isEnabled, "When using `defaultBuilder` RUM feature should be disabled by default")
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
        }
        try verify(configuration: rumBuilder.enableTracing(false).build()) {
            // verify features:
            XCTAssertTrue(LoggingFeature.isEnabled)
            XCTAssertFalse(TracingFeature.isEnabled)
            XCTAssertTrue(RUMFeature.isEnabled, "When using `rumBuilder` RUM feature should be enabled by default")
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
        }

        try verify(configuration: defaultBuilder.enableRUM(true).build()) {
            // verify features:
            XCTAssertTrue(LoggingFeature.isEnabled)
            XCTAssertTrue(TracingFeature.isEnabled)
            XCTAssertFalse(RUMFeature.isEnabled, "When using `defaultBuilder` RUM feature cannot be enabled")
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
            // verify integrations:
            XCTAssertNotNil(TracingFeature.instance?.loggingFeatureAdapter)
        }
        try verify(configuration: rumBuilder.enableRUM(false).build()) {
            // verify features:
            XCTAssertTrue(LoggingFeature.isEnabled)
            XCTAssertTrue(TracingFeature.isEnabled)
            XCTAssertFalse(RUMFeature.isEnabled)
            XCTAssertNil(RUMAutoInstrumentation.instance)
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
            // verify integrations:
            XCTAssertNotNil(TracingFeature.instance?.loggingFeatureAdapter)
        }

        try verify(configuration: rumBuilder.trackUIKitRUMViews(using: UIKitRUMViewsPredicateMock()).build()) {
            XCTAssertTrue(RUMFeature.isEnabled)
            XCTAssertNotNil(RUMAutoInstrumentation.instance?.views)
            XCTAssertNil(RUMAutoInstrumentation.instance?.userActions)
        }
        try verify(
            configuration: rumBuilder.enableRUM(false).trackUIKitRUMViews(using: UIKitRUMViewsPredicateMock()).build()
        ) {
            XCTAssertFalse(RUMFeature.isEnabled)
            XCTAssertNil(RUMAutoInstrumentation.instance?.views)
            XCTAssertNil(RUMAutoInstrumentation.instance?.userActions)
        }

        try verify(configuration: rumBuilder.trackUIKitActions(true).build()) {
            XCTAssertTrue(RUMFeature.isEnabled)
            XCTAssertNil(RUMAutoInstrumentation.instance?.views)
            XCTAssertNotNil(RUMAutoInstrumentation.instance?.userActions)
        }
        try verify(
            configuration: rumBuilder.enableRUM(false).trackUIKitActions(true).build()
        ) {
            XCTAssertFalse(RUMFeature.isEnabled)
            XCTAssertNil(RUMAutoInstrumentation.instance?.views)
            XCTAssertNil(RUMAutoInstrumentation.instance?.userActions)
        }

        try verify(configuration: defaultBuilder.trackURLSession(firstPartyHosts: ["example.com"]).build()) {
            XCTAssertNotNil(URLSessionAutoInstrumentation.instance)
        }
        try verify(configuration: defaultBuilder.trackURLSession().build()) {
            XCTAssertNil(URLSessionAutoInstrumentation.instance)
        }
    }

    // MARK: - Global Values

    func testTrackingConsent() throws {
        let initialConsent: TrackingConsent = .mockRandom()
        let nextConsent: TrackingConsent = .mockRandom()

        Datadog.initialize(
            appContext: .mockAny(),
            trackingConsent: initialConsent,
            configuration: defaultBuilder.build()
        )

        XCTAssertEqual(Datadog.instance?.consentProvider.currentValue, initialConsent)

        Datadog.set(trackingConsent: nextConsent)

        XCTAssertEqual(Datadog.instance?.consentProvider.currentValue, nextConsent)

        try Datadog.deinitializeOrThrow()
    }

    func testUserInfo() throws {
        Datadog.initialize(
            appContext: .mockAny(),
            trackingConsent: .mockRandom(),
            configuration: defaultBuilder.build()
        )

        XCTAssertNotNil(Datadog.instance?.userInfoProvider.value)
        XCTAssertNil(Datadog.instance?.userInfoProvider.value.id)
        XCTAssertNil(Datadog.instance?.userInfoProvider.value.email)
        XCTAssertNil(Datadog.instance?.userInfoProvider.value.name)
        XCTAssertEqual(Datadog.instance?.userInfoProvider.value.extraInfo as? [String: Int], [:])

        Datadog.setUserInfo(
            id: "foo",
            name: "bar",
            email: "foo@bar.com",
            extraInfo: ["abc": 123]
        )

        XCTAssertEqual(Datadog.instance?.userInfoProvider.value.id, "foo")
        XCTAssertEqual(Datadog.instance?.userInfoProvider.value.name, "bar")
        XCTAssertEqual(Datadog.instance?.userInfoProvider.value.email, "foo@bar.com")
        XCTAssertEqual(Datadog.instance?.userInfoProvider.value.extraInfo as? [String: Int], ["abc": 123])

        try Datadog.deinitializeOrThrow()
    }

    func testDefaultVerbosityLevel() {
        XCTAssertNil(Datadog.verbosityLevel)
    }

    func testDefaultDebugRUM() {
        XCTAssertFalse(Datadog.debugRUM)
    }

    func testDeprecatedAPIs() throws {
        (Datadog.self as DatadogDeprecatedAPIs.Type).initialize(
            appContext: .mockAny(),
            configuration: defaultBuilder.build()
        )

        XCTAssertEqual(
            Datadog.instance?.consentProvider.currentValue,
            .granted,
            "When using deprecated Datadog initialization API the consent should be set to `.granted`"
        )

        try Datadog.deinitializeOrThrow()
    }
}

/// An assistant protocol to shim the deprecated APIs and call them with no compiler warning.
private protocol DatadogDeprecatedAPIs {
    static func initialize(appContext: AppContext, configuration: Datadog.Configuration)
}
extension Datadog: DatadogDeprecatedAPIs {}

class AppContextTests: XCTestCase {
    func testBundleType() {
        let iOSAppBundle: Bundle = .mockWith(bundlePath: "mock.app")
        let iOSAppExtensionBundle: Bundle = .mockWith(bundlePath: "mock.appex")
        XCTAssertEqual(AppContext(mainBundle: iOSAppBundle).bundleType, .iOSApp)
        XCTAssertEqual(AppContext(mainBundle: iOSAppExtensionBundle).bundleType, .iOSAppExtension)
    }

    func testBundleIdentifier() throws {
        XCTAssertEqual(AppContext(mainBundle: .mockWith(bundleIdentifier: "com.abc.app")).bundleIdentifier, "com.abc.app")
        XCTAssertNil(AppContext(mainBundle: .mockWith(bundleIdentifier: nil)).bundleIdentifier)
    }

    func testBundleVersion() throws {
        XCTAssertEqual(
            AppContext(mainBundle: .mockWith(CFBundleVersion: "1.0", CFBundleShortVersionString: "1.0.0")).bundleVersion,
            "1.0.0"
        )
        XCTAssertEqual(
            AppContext(mainBundle: .mockWith(CFBundleVersion: nil, CFBundleShortVersionString: "1.0.0")).bundleVersion,
            "1.0.0"
        )
        XCTAssertEqual(
            AppContext(mainBundle: .mockWith(CFBundleVersion: "1.0", CFBundleShortVersionString: nil)).bundleVersion,
            "1.0"
        )
        XCTAssertNil(
            AppContext(mainBundle: .mockWith(CFBundleVersion: nil, CFBundleShortVersionString: nil)).bundleVersion
        )
    }

    func testBundleName() throws {
        XCTAssertEqual(
            AppContext(mainBundle: .mockWith(bundlePath: .mockAny(), CFBundleExecutable: "FooApp")).bundleName,
            "FooApp"
        )
    }
}
