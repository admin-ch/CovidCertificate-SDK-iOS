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

    private static let falseConstant = "false"

    private static let trueConstant = "true"

    private static let maximumNumberOfRequests = 20

    // MARK: - Update

    override func synchronousUpdate(ignoreLocalCache: Bool = false) -> NetworkError? {
        var listNeedsUpdate = true
        var requestsCount = 0

        while listNeedsUpdate, requestsCount < Self.maximumNumberOfRequests {
            requestsCount = requestsCount + 1

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

            // get the `x-next-since` from HTTP headers, save it and pass to the next request
            guard let nextSinceHeader = httpResponse.value(forHeaderField: "x-next-since") else {
                return .NETWORK_PARSE_ERROR
            }

            nextSince = nextSinceHeader

            // get the `up-to-date` from HTTP headers to decide whether we are at the end
            guard let upToDate = httpResponse.value(forHeaderField: "up-to-date") else {
                return .NETWORK_PARSE_ERROR
            }

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

            // start another request, as long as revocations are coming in
            listNeedsUpdate = upToDate == Self.falseConstant
        }
        return nil
    }

    override func isListStillValid() -> Bool {
        return trustStorage.revocationListIsValid()
    }
}
