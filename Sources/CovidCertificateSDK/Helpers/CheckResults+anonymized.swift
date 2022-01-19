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

extension CheckResults {
    var anonymized: CheckResults {
        switch nationalRules {
        // don't expose the validity range for verification apps
        case let .success(nationalRulesResult):
            return CheckResults(signature: signature,
                                revocationStatus: revocationStatus,
                                nationalRules: .success(.init(isValid: nationalRulesResult.isValid,
                                                              validUntil: nil,
                                                              validFrom: nil,
                                                              dateError: nil,
                                                              isSwitzerlandOnly: nil,
                                                              eolBannerIdentifier: nil)),
                                modeResults: modeResults)
        // expose networking errors for verification apps
        case .failure(.NETWORK_NO_INTERNET_CONNECTION),
             .failure(.NETWORK_PARSE_ERROR),
             .failure(.NETWORK_ERROR),
             .failure(.TIME_INCONSISTENCY(timeShift: _)):
            return self
        case .failure:
            // Strip specific national rules error for verification apps
            return .init(signature: signature,
                         revocationStatus: revocationStatus,
                         nationalRules: .failure(.UNKNOWN_CERTLOGIC_FAILURE),
                         modeResults: modeResults)
        }
    }
}
