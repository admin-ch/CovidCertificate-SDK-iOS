/*
 * Copyright (c) 2021 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import XCTest
@testable import CovidCertificateSDK

final class DateTests: XCTestCase {
    
    func testISO8601Formatter() {
        let iso8601WithoutTime = "2021-06-07"
        XCTAssertNotNil(Date.fromISO8601(iso8601WithoutTime))

        let iso8601WithSeconds = "2021-05-25T09:16:48Z"
        XCTAssertNotNil(Date.fromISO8601(iso8601WithSeconds))

        let iso8601WithFractionals = "2021-05-25T09:16:48.063Z"
        XCTAssertNotNil(Date.fromISO8601(iso8601WithFractionals))

    }
}
