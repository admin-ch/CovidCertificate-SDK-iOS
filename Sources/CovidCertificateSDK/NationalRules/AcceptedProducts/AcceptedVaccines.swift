//
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

class AcceptedVaccines: Codable {
    var id: String
    var date: String
    var version: String
    var entries: [AcceptedVaccine]

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case date = "Date"
        case version = "Version"
        case entries
    }
}

class AcceptedVaccine: Codable {
    var name: String
    var code: String
    var prophylaxis: String
    var prophylaxisCode: String
    var authHolder: String
    var authHolderCode: String
    var totalDosisNumber: UInt64
    var active: Bool

    private enum CodingKeys: String, CodingKey {
        case name, code, active, prophylaxis
        case prophylaxisCode = "prophylaxis_code"
        case authHolder = "auth_holder"
        case authHolderCode = "auth_holder_code"
        case totalDosisNumber = "total_dosis_number"
    }
}
