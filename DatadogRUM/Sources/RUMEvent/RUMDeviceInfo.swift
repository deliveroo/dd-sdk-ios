/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogInternal

extension RUMDevice {
    init(
        context: DatadogContext,
        telemetry: Telemetry = NOPTelemetry()
    ) {
        self.init(
            device: context.device,
            telemetry: telemetry
        )
    }

    init(
        device: DeviceInfo,
        telemetry: Telemetry = NOPTelemetry()
    ) {
        self.init(
            architecture: device.architecture,
            brand: device.brand,
            model: device.model,
            name: device.name,
            type: {
                switch device.type {
                case .iPhone, .iPod: return .mobile
                case .iPad: return .tablet
                case .appleTV: return .tv
                case .other(modelName: let modelName, osName: let osName):
                    telemetry.debug("Failed to map `device.model`: \(modelName) and `os.name`: \(osName) to any `RUMDeviceType`")
                    return .other
                }
            }()
        )
    }
}
