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

    let session = URLSession.shared

    // MARK: - Update

    override internal func synchronousUpdate() -> NetworkError? {
        // update active certificates service
        let requestActive = CovidCertificateSDK.currentEnvironment.activeCertificatesService.request()
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

        _ = trustStorage.updateActiveCertificates(result)

        // update trust certificates service
        var listNeedsUpdate = true

        while listNeedsUpdate {
            let request = CovidCertificateSDK.currentEnvironment.trustCertificatesService(since: trustStorage.certificateSince()).request()
            let (data, response, error) = session.synchronousDataTask(with: request)

            if error != nil {
                return error?.asNetworkError()
            }

            // get the x-next-since, save it as well and pass to the next request
            var nextSinceHeader: String = ""
            if let s = (response as? HTTPURLResponse)?.allHeaderFields["x-next-since"] as? String {
                nextSinceHeader = s
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
            listNeedsUpdate = result.certs.count > 0
        }

        return nil
    }

    override internal func isListStillValid() -> Bool {
        return trustStorage.certificateListIsValid()
    }
}
