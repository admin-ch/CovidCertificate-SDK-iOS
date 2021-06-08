/*
 * Copyright (c) 2021 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

@testable import CovidCertificateSDK
import XCTest

final class DateTests: XCTestCase {
    func testISO8601Formatter() {
        let iso8601WithoutTime = "2021-06-07"
        // We do not accept this a ISO8601 timestamp since it contains no timezone information and no time of day.
        XCTAssertNil(Date.fromISO8601(iso8601WithoutTime))

        let iso8601WithSeconds = "2021-05-25T09:16:48Z"
        XCTAssertNotNil(Date.fromISO8601(iso8601WithSeconds))
        let comparisonIso8601WithSeconds = Calendar.current.date(from: DateComponents(timeZone: NSTimeZone(name: "UTC")! as TimeZone, year: 2021, month: 5, day: 25, hour: 9, minute: 16, second: 48, nanosecond: 0))
        XCTAssertEqual(comparisonIso8601WithSeconds!, Date.fromISO8601(iso8601WithSeconds)!)

        let iso8601WithFractionals = "2021-05-25T09:16:48.063Z"
        XCTAssertNotNil(Date.fromISO8601(iso8601WithFractionals))
        let comparisonIso8601WithFractionals = Calendar.current.date(from: DateComponents(timeZone: NSTimeZone(name: "UTC")! as TimeZone, year: 2021, month: 5, day: 25, hour: 9, minute: 16, second: 48, nanosecond: 63_000_000))
        XCTAssertEqual(comparisonIso8601WithFractionals, Date.fromISO8601(iso8601WithFractionals))

        let iso8601WithManyFractionals = "2021-05-27T10:56:50.482139Z"
        XCTAssertNotNil(Date.fromISO8601(iso8601WithManyFractionals))
        // precision while parsing is different than platform
        let comparisonIso8601WithManyFractionalsSlightlyBefore = Calendar.current.date(from: DateComponents(timeZone: NSTimeZone(name: "UTC")! as TimeZone, year: 2021, month: 5, day: 27, hour: 10, minute: 56, second: 50, nanosecond: 482_000_000))
        let comparisonIso8601WithManyFractionalsSlightlyAfter = Calendar.current.date(from: DateComponents(timeZone: NSTimeZone(name: "UTC")! as TimeZone, year: 2021, month: 5, day: 27, hour: 10, minute: 56, second: 50, nanosecond: 482_140_000))
        XCTAssertTrue(comparisonIso8601WithManyFractionalsSlightlyBefore!.isBefore(Date.fromISO8601(iso8601WithManyFractionals)!))
        XCTAssertTrue(comparisonIso8601WithManyFractionalsSlightlyAfter!.isAfter(Date.fromISO8601(iso8601WithManyFractionals)!))
    }
}
