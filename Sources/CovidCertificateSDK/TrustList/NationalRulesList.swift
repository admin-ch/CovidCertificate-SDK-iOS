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
                let json = JSON(newValue)
                rules = json["rules"]
                valueSets = json["valueSets"]
                displayRules = json["displayRules"]
                modeRules.activeModes = (json["modeRules"].dictionary?["activeModes"]?.array?.compactMap {
                    if let id = $0["id"].string, let dn = $0["displayName"].string {
                        return CheckMode(id: id, displayName: dn)
                    } else {
                        return nil
                    }
                }) ?? []

                modeRules.verifierActiveModes = (json["modeRules"].dictionary?["verifierActiveModes"]?.array?.compactMap {
                    if let id = $0["id"].string, let dn = $0["displayName"].string {
                        return CheckMode(id: id, displayName: dn)
                    } else {
                        return nil
                    }
                }) ?? []

                modeRules.logic = json["modeRules"].dictionary?["logic"]
            } else {
                rules = nil
                valueSets = nil
                displayRules = nil
                modeRules = .init()
            }
        }
    }

    var rules: JSON? = nil
    var valueSets: JSON? = nil
    var displayRules: JSON? = nil
    var modeRules: NationalRulesModes = .init()

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
            let json = JSON(newValue)
            rules = json["rules"]
            valueSets = json["valueSets"]
            displayRules = json["displayRules"]
            modeRules.activeModes = getCheckModes(json: json["modeRules"].dictionary?["activeModes"])
            modeRules.verifierActiveModes = getCheckModes(json: json["modeRules"].dictionary?["verifierActiveModes"])
            modeRules.logic = json["modeRules"].dictionary?["logic"]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(validDuration, forKey: .validDuration)
        try container.encode(requestData, forKey: .requestData)
    }

    func getList(for _: CheckMode) -> JSON? {
        nil
    }

    private func getCheckModes(json : JSON?) -> [CheckMode] {
        return (json?.array?.compactMap {
            if let id = $0["id"].string, let dn = $0["displayName"].string {
                return CheckMode(id: id, displayName: dn)
            } else {
                return nil
            }
        }) ?? []
    }
}

class NationalRulesModes {
    var activeModes: [CheckMode] = []
    var verifierActiveModes: [CheckMode] = []
    var logic: JSON?
}
