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
    
    private let session = URLSession.certificatePinned
    
    @UBUserDefault(key: "covidcertificate.foreignCountries.list", defaultValue: [])
    var storedForeignCountries: [ArrivalCountry.ID]
    
    @UBUserDefault(key: "covidcertificate.foreignCountries.validUntil", defaultValue: nil)
    var validUntil: Date?
    
    func nationalRulesListIsStillValid(arrivalCountry: ArrivalCountry) -> Bool {
        let nationalList = NationalRulesStorage.shared.getNationalRulesListEntry(countryCode: arrivalCountry.id)
        return nationalList?.isValid ?? false
    }
    
    func updateNationalRules(countryCode: ArrivalCountry.ID, nationalRulesList: NationalRulesList) -> Bool {
        return NationalRulesStorage.shared.updateOrInsertNationalRulesList(list: nationalRulesList, countryCode: countryCode)
    }
    
    func nationalRulesList(countryCode: ArrivalCountry.ID) -> NationalRulesList {
        guard let listEntry = NationalRulesStorage.shared.getNationalRulesListEntry(countryCode: countryCode), listEntry.isValid else {
            return NationalRulesList()
        }
        return listEntry.nationalRulesList
    }
    
    func foreignCountries(_ completionHandler: @escaping (Result<[ArrivalCountry], NetworkError>) -> Void) {
        let request = CovidCertificateSDK.currentEnvironment.foreignCountriesService().request(reloadRevalidatingCacheData: false)

        let (data, response, error) = session.synchronousDataTask(with: request)
        
        if error != nil {
            completionHandler(handleError(error!.asNetworkError()))
            return
        }
        
        guard let d = data,
              let httpResponse = response as? HTTPURLResponse else {
            completionHandler(handleError(.NETWORK_PARSE_ERROR))
            return
        }
        
        // Make sure HTTP response code is 2xx
        guard httpResponse.statusCode / 100 == 2 else {
            completionHandler(handleError(.NETWORK_SERVER_ERROR(statusCode: httpResponse.statusCode)))
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Swift.Result<ArrivalCountries, JWSError> = .failure(.SIGNATURE_INVALID)
        
        TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: d) { (result: Swift.Result<ArrivalCountries, JWSError>) in
            outcome = result
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard let result = try? outcome.get() else {
            completionHandler(handleError(.NETWORK_PARSE_ERROR))
            return
        }
        
        validUntil = Date() // TODO: IZ-954 Read validUntil from request
        let countries = result.toArrivalCountryList()
        storedForeignCountries = result.countries
        completionHandler(.success(countries))
    }
    
    private func handleError(_ error: NetworkError) -> Swift.Result<[ArrivalCountry], NetworkError> {
        if !storedForeignCountries.isEmpty, let validUntil = validUntil, validUntil >= Date() {
            return .success(storedForeignCountries.map{ArrivalCountry(countryCode: $0)}.compactMap ({ $0 }))
        } else {
            return .failure(error)
        }
    }
}

extension Array: JWTExtension where Element: JWTExtension {
}
