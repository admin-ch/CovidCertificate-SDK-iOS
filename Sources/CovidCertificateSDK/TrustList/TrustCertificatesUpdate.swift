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

class TrustCertificatesUpdate : TrustListUpdate {
    // MARK: - Session

    let session = URLSession.shared

    // MARK: - Update

    internal override func synchronousUpdate() -> ValidationError? {
        // update active certificates service
        let requestActive = CovidCertificateSDK.currentEnvironment.activeCertificatesService.request()
        let (dataActive, _, errorActive) = session.synchronousDataTask(with: requestActive)

        if errorActive != nil {
            return .NETWORK_ERROR
        }

        guard let d = dataActive, let result = try? JSONDecoder().decode(ActiveTrustCertificates.self, from: d) else {
            return .NETWORK_PARSE_ERROR
        }

        let _ = self.trustStorage.updateActiveCertificates(result)

        // update trust certificates service

        // TODO: retry until all data is here (check header)
        let request = CovidCertificateSDK.currentEnvironment.trustCertificatesService.request()
        let (data, _, error) = session.synchronousDataTask(with: request)

        if error != nil {
            return .NETWORK_ERROR
        }

        guard let d = data, let result = try? JSONDecoder().decode(TrustCertificates.self, from: d) else {
            return .NETWORK_PARSE_ERROR
        }

        let _ = self.trustStorage.updateCertificateList(result)

        return nil
    }
}
