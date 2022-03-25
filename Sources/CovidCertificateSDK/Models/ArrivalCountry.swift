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


public class ArrivalCountry: Codable, UBUserDefaultValue, JWTExtension {
    typealias ID = String
    
    let id: ID
    
    let localizedName: String
    
    init?(countryCode: ID) {
        // TODO: IZ-954 Check identifiers
        guard let name = Locale.current.localizedString(forRegionCode: countryCode.lowercased()) else { return nil }

        self.id = countryCode
        self.localizedName = name
    }
    
    static var Switzerland: ArrivalCountry {
        return .init(countryCode: "CH")!
    }
    
    var isSwitzerland: Bool {
        return id == ArrivalCountry.Switzerland.id
    }
}

extension Array where Element == ArrivalCountry {
    var sortedByLocalizedName: [ArrivalCountry] {
        self.sorted { $0.localizedName.localizedCompare($1.localizedName) == .orderedAscending }
    }
}
