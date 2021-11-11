/*
 * Copyright (c) 2021 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation

/// Configure advanced options of the SDK
public struct SDKOptions {
    public static let defaultAllowedServerTimeDiff: TimeInterval = 60 * 60 * 2

    public static let defaultTimeshiftDetectionEnabled: Bool = false

    /// Option to disable certificate pinning of TLS requests for debugging
    public var certificatePinning: Bool

    /// The server time difference that devices are allowed to have without showing a warning
    public var allowedServerTimeDiff: TimeInterval

    /// Option to enable/disable timeshift detection for verification operations
    public var timeshiftDetectionEnabled: Bool

    public init(certificatePinning: Bool = true,
                allowedServerTimeDiff: TimeInterval = Self.defaultAllowedServerTimeDiff,
                timeshiftDetectionEnabled: Bool = Self.defaultTimeshiftDetectionEnabled) {
        self.certificatePinning = certificatePinning
        self.allowedServerTimeDiff = allowedServerTimeDiff
        self.timeshiftDetectionEnabled = timeshiftDetectionEnabled
    }
}
