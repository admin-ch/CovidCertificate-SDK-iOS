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

public enum CertificateType: CaseIterable {
    case dccCert
    case lightCert

    var prefix: String {
        switch self {
        case .dccCert: return "HC1:"
        case .lightCert: return "LT1:"
        }
    }

    var trustListUseFilters: [String] {
        switch self {
        case .dccCert: return ["sig", "t", "v", "r"]
        case .lightCert: return ["sig", "l"]
        }
    }
}
