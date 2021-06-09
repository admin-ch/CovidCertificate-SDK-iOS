//
//  File.swift
//  
//
//  Created by Marco Zimmermann on 09.06.21.
//

import Foundation

class NationalRulesListUpdate : TrustListUpdate {
    // MARK: - Session

    let session = URLSession.shared

    // MARK: - Update

    internal override func synchronousUpdate() -> NetworkError? {
        let request = CovidCertificateSDK.currentEnvironment.nationalRulesListService.request()
        let (data, _, error) = session.synchronousDataTask(with: request)

        if error != nil {
            return error?.asNetworkError()
        }

        guard let d = data, let result = try? JSONDecoder().decode(NationalRulesList.self, from: d) else {
            return .NETWORK_PARSE_ERROR
        }

        let _ = self.trustStorage.updateNationalRules(result)
        return nil
    }

    internal override func isListStillValid() -> Bool {
        return self.trustStorage.nationalRulesListIsStillValid()
    }
}
