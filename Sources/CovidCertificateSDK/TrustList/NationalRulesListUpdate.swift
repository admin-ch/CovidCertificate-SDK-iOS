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

class NationalRulesListUpdate: TrustListUpdate {
    // MARK: - Session

    let session = URLSession.certificatePinned

    // MARK: - Update

    override func synchronousUpdate(ignoreLocalCache: Bool = false) -> NetworkError? {
        let request = CovidCertificateSDK.currentEnvironment.nationalRulesListService.request(reloadRevalidatingCacheData: ignoreLocalCache)
        let (data, _, error) = session.synchronousDataTask(with: request)

        if error != nil {
            return error?.asNetworkError()
        }

        guard let d = data else {
            return .NETWORK_PARSE_ERROR
        }

        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<NationalRulesList, JWSError> = .failure(.SIGNATURE_INVALID)

        TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: d) { (result: Result<NationalRulesList, JWSError>) in
            outcome = result
            semaphore.signal()
        }

        semaphore.wait()

        guard let result = try? outcome.get() else {
            return .NETWORK_PARSE_ERROR
        }

        let jwtString = String(data: d, encoding: .utf8)!
        let components = jwtString.components(separatedBy: ".")
        guard components.count == 2 || components.count == 3,
              let claimsData = Data.data(base64urlEncoded: components[1])
        else {
            return .NETWORK_PARSE_ERROR
        }
        result.requestData = claimsData
        _ = trustStorage.updateNationalRules(result)
        return nil
    }

    override func isListStillValid() -> Bool {
        trustStorage.nationalRulesListIsStillValid()
    }
}

extension Data {
    static func data(base64urlEncoded: String) -> Data? {
        let paddingLength = 4 - base64urlEncoded.count % 4
        let padding = (paddingLength < 4) ? String(repeating: "=", count: paddingLength) : ""
        let base64EncodedString = base64urlEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            + padding
        return Data(base64Encoded: base64EncodedString)
    }
}
