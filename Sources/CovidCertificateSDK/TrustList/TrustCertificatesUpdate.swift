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

class TrustCertificatesUpdate: TrustListUpdate {
    // MARK: - Session

    let session = URLSession.certificatePinned

    private static let falseConstant = "false"
    private static let trueConstant = "true"
    private static let maximumNumberOfRequests = 20

    // MARK: - Update

    override func synchronousUpdate(ignoreLocalCache: Bool = false) -> NetworkError? {
        // update active certificates service
        let requestActive = CovidCertificateSDK.currentEnvironment.activeCertificatesService.request(reloadIgnoringLocalCache: ignoreLocalCache)
        let (dataActive, _, errorActive) = session.synchronousDataTask(with: requestActive)

        if errorActive != nil {
            return errorActive?.asNetworkError()
        }

        guard let d = dataActive else {
            return .NETWORK_PARSE_ERROR
        }

        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<ActiveTrustCertificates, JWSError> = .failure(.SIGNATURE_INVALID)

        TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: d) { (result: Result<ActiveTrustCertificates, JWSError>) in
            outcome = result
            semaphore.signal()
        }

        semaphore.wait()

        guard let result = try? outcome.get() else {
            return .NETWORK_PARSE_ERROR
        }

        // update trust certificates service
        var listNeedsUpdate = true
        var requestsCount = 0

        while listNeedsUpdate, requestsCount < Self.maximumNumberOfRequests {
            requestsCount = requestsCount + 1

            let request = CovidCertificateSDK.currentEnvironment.trustCertificatesService(since: trustStorage.certificateSince()).request(reloadIgnoringLocalCache: ignoreLocalCache)
            let (data, response, error) = session.synchronousDataTask(with: request)

            if error != nil {
                return error?.asNetworkError()
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return .NETWORK_PARSE_ERROR
            }

            // get the `x-next-since` from HTTP headers, save it and pass to the next request
            guard let nextSinceHeader = httpResponse.value(forHeaderField: "x-next-since") else {
                return .NETWORK_PARSE_ERROR
            }

            // get the `up-to-date` from HTTP headers to decide whether we are at the end
            guard let upToDate = httpResponse.value(forHeaderField: "up-to-date") else {
                return .NETWORK_PARSE_ERROR
            }

            guard let d = data else {
                return .NETWORK_PARSE_ERROR
            }

            let semaphore = DispatchSemaphore(value: 0)
            var outcome: Result<TrustCertificates, JWSError> = .failure(.SIGNATURE_INVALID)

            TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: d) { (result: Result<TrustCertificates, JWSError>) in
                outcome = result
                semaphore.signal()
            }

            semaphore.wait()

            guard let result = try? outcome.get() else {
                return .NETWORK_PARSE_ERROR
            }

            _ = trustStorage.updateCertificateList(result, since: nextSinceHeader)

            // start another request, as long as certificates are coming in
            listNeedsUpdate = upToDate == Self.falseConstant
        }

        // Check which certificates need to be removed. This needs to be called
        // after loading new certificates and only if it was successful.
        _ = trustStorage.updateActiveCertificates(result)

        // TODO: return an error if we hit the circuit breaker
        return nil
    }

    override func isListStillValid() -> Bool {
        return trustStorage.certificateListIsValid()
    }
}
