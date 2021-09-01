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
import JSON

class NationalRulesList: Codable, JWTExtension {
    var validDuration: Int64 = 0
    var requestData: Data? {
        didSet {
            if let newValue = requestData {
                rules = JSON(newValue)["rules"]
                valueSets = JSON(newValue)["valueSets"]
                displayRules = JSON(newValue)["displayRules"]
            } else {
                rules = nil
                valueSets = nil
            }
        }
    }

    var rules: JSON? = nil
    var valueSets: JSON? = nil
    var displayRules : JSON? = nil

    enum CodingKeys: String, CodingKey {
        case validDuration
        case requestData
    }

    // Allow default constructor
    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        validDuration = try container.decode(Int64.self, forKey: .validDuration)
        requestData = try? container.decode(Data.self, forKey: .requestData)

        if let newValue = requestData {
            rules = JSON(newValue)["rules"]
            valueSets = JSON(newValue)["valueSets"]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(validDuration, forKey: .validDuration)
        try container.encode(requestData, forKey: .requestData)
    }
}
