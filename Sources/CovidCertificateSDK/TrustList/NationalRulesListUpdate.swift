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

class NationalRulesListUpdate: TrustListUpdate {
    // MARK: - Session

    let session = URLSession.shared

    // MARK: - Update

    override internal func synchronousUpdate() -> NetworkError? {
        let request = CovidCertificateSDK.currentEnvironment.nationalRulesListService.request()
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
        _ = trustStorage.updateNationalRules(result)
        return nil
    }

    override internal func isListStillValid() -> Bool {
        return trustStorage.nationalRulesListIsStillValid()
    }
}
