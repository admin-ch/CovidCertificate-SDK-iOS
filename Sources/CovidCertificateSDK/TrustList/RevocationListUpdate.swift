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

    private let session: URLSession

    private let decoder: RevocationListDecoder

    private static let falseConstant = "false"

    private static let trueConstant = "true"

    private static let maximumNumberOfRequests = 20

    init(trustStorage: TrustStorageProtocol, decoder: RevocationListDecoder = RevocationListJWSDecoder(), session: URLSession = .certificatePinned) {
        self.decoder = decoder
        self.session = session
        super.init(trustStorage: trustStorage)
    }

    // MARK: - Update

    override func synchronousUpdate(ignoreLocalCache: Bool = false, countryCode _: String = CountryCodes.Switzerland) -> NetworkError? {
        var listNeedsUpdate = true
        var requestsCount = 0

        while listNeedsUpdate, requestsCount < Self.maximumNumberOfRequests {
            requestsCount = requestsCount + 1

            // download data and update local storage
            let request = CovidCertificateSDK.currentEnvironment.revocationListService(since: trustStorage.revocationListNextSince).request(reloadIgnoringLocalCache: ignoreLocalCache)
            let (data, response, error) = session.synchronousDataTask(with: request)

            // Only run timeshift detection if request does not come from cache
            // as otherwise "Date" and "Age" headers might not be current
            if ignoreLocalCache,
               let httpResponse = response as? HTTPURLResponse,
               let timeShiftError = detectTimeshift(response: httpResponse) {
                return timeShiftError
            }

            if error != nil {
                return error?.asNetworkError()
            }

            guard let d = data,
                  let httpResponse = response as? HTTPURLResponse else {
                return .NETWORK_PARSE_ERROR
            }

            // Make sure HTTP response code is 2xx
            guard httpResponse.statusCode / 100 == 2 else {
                return .NETWORK_SERVER_ERROR(statusCode: httpResponse.statusCode)
            }

            // get the `x-next-since` from HTTP headers, save it and pass to the next request
            guard let nextSinceHeader = httpResponse.value(forHeaderField: "x-next-since") else {
                return .NETWORK_PARSE_ERROR
            }

            // get the `up-to-date` from HTTP headers to decide whether we are at the end
            guard let upToDate = httpResponse.value(forHeaderField: "up-to-date") else {
                return .NETWORK_PARSE_ERROR
            }

            guard let result = decoder.decode(d) else {
                return .NETWORK_PARSE_ERROR
            }

            let success = trustStorage.updateRevocationList(result, nextSince: nextSinceHeader)
            assert(success)

            // start another request, as long as revocations are coming in
            listNeedsUpdate = upToDate == Self.falseConstant
        }
        return nil
    }

    override func isListStillValid() -> Bool {
        trustStorage.revocationListIsValid()
    }
}

protocol RevocationListDecoder {
    func decode(_ data: Data) -> RevocationList?
}

class RevocationListJWSDecoder: RevocationListDecoder {
    func decode(_ data: Data) -> RevocationList? {
        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<RevocationList, JWSError> = .failure(.SIGNATURE_INVALID)

        TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: data) { (result: Result<RevocationList, JWSError>) in
            outcome = result
            semaphore.signal()
        }

        semaphore.wait()

        return try? outcome.get()
    }
}
