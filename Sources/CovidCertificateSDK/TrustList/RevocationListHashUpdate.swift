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

class RevocationListHashUpdate: TrustListUpdate {
    // MARK: - Session

    private let session: URLSession

    private let decoder: RevocationListDecoder

    private static let falseConstant = "false"

    private static let trueConstant = "true"

    private static let maximumNumberOfRequests = 20
    
    public var holders: [CertificateHolder] = []

    init(trustStorage: TrustStorageProtocol, decoder: RevocationListDecoder = RevocationListJWSDecoder(), session: URLSession = .certificatePinned) {
        self.decoder = decoder
        //TODO: DE, change to session whenever JWS works
        self.session = URLSession.shared
        super.init(trustStorage: trustStorage)
    }

    // MARK: - Update

    override func synchronousUpdate(ignoreLocalCache: Bool = false) -> NetworkError? {
        var listNeedsUpdate = true
        var requestsCount = 0

        while listNeedsUpdate, requestsCount < Self.maximumNumberOfRequests {
            requestsCount = requestsCount + 1

            // download data and update local storage
            //TODO: DE, change to actually make request for specific certificate
            let request = CovidCertificateSDK.currentEnvironment.revocationListHashService().request(reloadIgnoringLocalCache: ignoreLocalCache)
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

            //TODO: DE, Currently we don't have next-since & up-to-date header on test-request (add nextSinceHeader in updateRevocationHashes())
            // get the `x-next-since` from HTTP headers, save it and pass to the next request
//            guard let nextSinceHeader = httpResponse.value(forHeaderField: "x-next-since") else {
//                return .NETWORK_PARSE_ERROR
//            }

            // get the `up-to-date` from HTTP headers to decide whether we are at the end
//            guard let upToDate = httpResponse.value(forHeaderField: "up-to-date") else {
//                return .NETWORK_PARSE_ERROR
//            }

            guard let result = decoder.decode(d) else {
                return .NETWORK_PARSE_ERROR
            }

            let success = trustStorage.updateRevocationHashes(result, nextSince: "")
            assert(success)

            // start another request, as long as revocations are coming in
            listNeedsUpdate = false //upToDate == Self.falseConstant
        }
        return nil
    }

    override func isListStillValid() -> Bool {
        trustStorage.revocationHashesAreValid()
    }
    
    override func isCertStillValid(_ holder: CertificateHolder) -> Bool {
        trustStorage.revocationHashIsValid(for: holder)
    }
}

protocol RevocationListDecoder {
    func decode(_ data: Data) -> RevocationHashes?
}

class RevocationListJWSDecoder: RevocationListDecoder {
    func decode(_ data: Data) -> RevocationHashes? {
        //TODO: DE, Currently this is not implemented with JWS yet
//        let semaphore = DispatchSemaphore(value: 0)
//        var outcome: Result<RevocationHashes, JWSError> = .failure(.SIGNATURE_INVALID)
//
//        TrustlistManager.jwsVerifier.verifyAndDecode(httpBody: data) { (result: Result<RevocationHashes, JWSError>) in
//            outcome = result
//            semaphore.signal()
//        }
//
//        semaphore.wait()
//
//        return try? outcome.get()
        let result = try? JSONDecoder().decode(RevocationHashes.self, from: data)
        
        return result
    }
}
