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
    
    @UBUserDefault(key: "covidcertificate.foreignRules.countryCodes", defaultValue: [])
    var foreignRulesCountryCodes: [String]
    
    @UBUserDefault(key: "covidcertificate.foreignRules.countryCodesValidUntil", defaultValue: Date())
    var foreignRulesCountryCodesValidUntil: Date
    
    var foreignRulesCountryCodesAreStillValid: Bool {
        return !foreignRulesCountryCodes.isEmpty &&  foreignRulesCountryCodesValidUntil > Date()
    }
    func nationalRulesAreStillValid(countryCode: String) -> Bool {
        let nationalList = NationalRulesStorage.shared.getNationalRulesListEntry(countryCode: countryCode)
        return nationalList?.isValid ?? false
    }
    
    func updateNationalRules(countryCode: String, nationalRulesList: NationalRulesList) -> Bool {
        return NationalRulesStorage.shared.updateOrInsertNationalRulesList(list: nationalRulesList, countryCode: countryCode)
    }
    
    func getNationalRules(countryCode: String) -> NationalRulesList {
        guard let listEntry = NationalRulesStorage.shared.getNationalRulesListEntry(countryCode: countryCode), listEntry.isValid else {
            return NationalRulesList()
        }
        return listEntry.nationalRulesList
    }
    
    func getForeignRulesCountryCodes(forceUpdate: Bool = false, _ completionHandler: @escaping (Result<[String], NetworkError>) -> Void) {
        let shouldLoadCountryCodes = forceUpdate || !foreignRulesCountryCodesAreStillValid

        if shouldLoadCountryCodes {
            let request = CovidCertificateSDK.currentEnvironment.foreignCountryCodesService().request(reloadRevalidatingCacheData: false)

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
            var outcome: Swift.Result<ForeignRulesCountryCodes, JWSError> = .failure(.SIGNATURE_INVALID)
            
            TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: d) { (result: Swift.Result<ForeignRulesCountryCodes, JWSError>) in
                outcome = result
                semaphore.signal()
            }
            
            semaphore.wait()
            
            guard let result = try? outcome.get() else {
                completionHandler(handleError(.NETWORK_PARSE_ERROR))
                return
            }
            
            foreignRulesCountryCodesValidUntil = Date().addingTimeInterval(5 * 60 * 60) // TODO: IZ-954 Read validUntil from request
            foreignRulesCountryCodes = result.countries
            completionHandler(.success(foreignRulesCountryCodes))
        } else {
            completionHandler(.success(foreignRulesCountryCodes))
        }
    }
    
    private func handleError(_ error: NetworkError) -> Swift.Result<[String], NetworkError> {
        if foreignRulesCountryCodesAreStillValid {
            return .success(foreignRulesCountryCodes)
        } else {
            return .failure(error)
        }
    }
}
