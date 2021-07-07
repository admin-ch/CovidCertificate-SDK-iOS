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

public protocol CovidCertificate {
    var person: Person { get }
    var dateOfBirth: String { get }
    var version: String { get }
    var type: CertificateType { get }
}

public extension CovidCertificate {
    var dateOfBirthFormatted: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: dateOfBirth) {
            let prettyDateFormatter = DateFormatter()
            prettyDateFormatter.dateFormat = "dd.MM.yyyy"
            return prettyDateFormatter.string(from: date)
        }

        // Fall back to raw value if we cannot parse it
        return dateOfBirth
    }
}
