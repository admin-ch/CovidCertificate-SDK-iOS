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

class RevocationListUpdate: TrustListUpdate {
    // MARK: - Session

    let session = URLSession.certificatePinned

    @UBUserDefault(key: "covidcertififcate.revocations.nextSince", defaultValue: nil)
    var nextSince: String?

    // MARK: - Update

    override func synchronousUpdate(ignoreLocalCache: Bool = false) -> NetworkError? {
        // download data and update local storage
        let request = CovidCertificateSDK.currentEnvironment.revocationListService(since: nextSince).request(reloadIgnoringLocalCache: ignoreLocalCache)
        let (data, response, error) = session.synchronousDataTask(with: request)

        if error != nil {
            return error?.asNetworkError()
        }

        guard let d = data,
              let httpResponse = response as? HTTPURLResponse else {
            return .NETWORK_PARSE_ERROR
        }

        nextSince = httpResponse.value(forHeaderField: "x-next-since")

        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<RevocationList, JWSError> = .failure(.SIGNATURE_INVALID)

        TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: d) { (result: Result<RevocationList, JWSError>) in
            outcome = result
            semaphore.signal()
        }

        semaphore.wait()

        guard let result = try? outcome.get() else {
            return .NETWORK_PARSE_ERROR
        }

        _ = trustStorage.updateRevocationList(result)
        return nil
    }

    override func isListStillValid() -> Bool {
        return trustStorage.revocationListIsValid()
    }
}
