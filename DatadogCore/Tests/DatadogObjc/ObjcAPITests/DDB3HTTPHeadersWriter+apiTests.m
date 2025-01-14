/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import DatadogObjc;

@interface DDB3HTTPHeadersWriter_apiTests : XCTestCase
@end

/*
 * `DatadogObjc` APIs smoke tests - only check if the interface is available to Objc.
 */
@implementation DDB3HTTPHeadersWriter_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

- (void)testInitWithSamplingRate {
    [[DDB3HTTPHeadersWriter alloc] initWithSamplingStrategy:[DDTraceSamplingStrategy headBased]
                                             injectEncoding:DDInjectEncodingSingle
                                      traceContextInjection:DDTraceContextInjectionAll];
    [[DDB3HTTPHeadersWriter alloc] initWithSamplingStrategy:[DDTraceSamplingStrategy customWithSampleRate:50]
                                             injectEncoding:DDInjectEncodingMultiple
                                      traceContextInjection:DDTraceContextInjectionAll];
}

#pragma clang diagnostic pop

@end
