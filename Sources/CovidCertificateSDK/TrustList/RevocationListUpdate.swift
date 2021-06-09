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

class RevocationListUpdate : TrustListUpdate {
    // MARK: - Session

    let session = URLSession.shared

    // MARK: - Update

    internal override func synchronousUpdate() -> ValidationError? {
        // download data and update local storage
        let request = CovidCertificateSDK.currentEnvironment.revocationListService.request()
        let (data, _, error) = session.synchronousDataTask(with: request)

        if error != nil {
            return .NETWORK_ERROR
        }

        guard let d = data, let result = try? JSONDecoder().decode(RevocationList.self, from: d) else {
            return .NETWORK_PARSE_ERROR
        }

        let _ = self.trustStorage.updateRevocationList(result)
        return nil
    }
}
