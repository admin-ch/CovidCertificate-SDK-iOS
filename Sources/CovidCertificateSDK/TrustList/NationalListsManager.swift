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

class NationalListsManager {
    static let shared = NationalListsManager()
    
    let session = URLSession.certificatePinned
    let nationalRulesStorage: NationalRulesStorage = NationalRulesStorage()

    
    @UBUserDefault(key: "covidcertificate.foreignCountries", defaultValue: nil)
    var storedForeignCountries: [ArrivalCountry]?
    
    @UBUserDefault(key: "covidcertificate.foreignCountries.validUntil", defaultValue: nil)
    var validUntil: Date?
    
    
    func nationalRulesListIsStillValid(arrivalCountry: ArrivalCountry) -> Bool {
        let nationalList = nationalRulesStorage.getNationalRulesListEntry(countryCode: arrivalCountry.id)
        return nationalList?.isValid ?? false
    }
    
    func updateNationalRules(countryCode: ArrivalCountry.ID, nationalRulesList: NationalRulesList) -> Bool {
        return nationalRulesStorage.updateOrInsertNationalRulesList(list: nationalRulesList, countryCode: countryCode)
    }
    
    func nationalRulesList(countryCode: ArrivalCountry.ID) -> NationalRulesList {
        guard let listEntry = nationalRulesStorage.getNationalRulesListEntry(countryCode: countryCode), listEntry.isValid else {
            return NationalRulesList()
        }
        return listEntry.nationalRulesList
    }
    
    func foreignCountries(_ completionHandler: @escaping (Result<[ArrivalCountry], NetworkError>) -> Void) {
        // TODO: IZ-954
        completionHandler(.success([.Switzerland]))
    }
    
    private func handleError(_ error: NetworkError) -> Swift.Result<[ArrivalCountry], NetworkError> {
        // Check if we have any offline date that is valid
        if let countries = storedForeignCountries, let validUntil = validUntil, validUntil > Date() {
            return .success(countries)
        } else {
            return .failure(error)
        }
    }
}

extension Array: JWTExtension where Element: JWTExtension {
}
