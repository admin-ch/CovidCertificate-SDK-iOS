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

public enum SDKEnvironment {
    case dev
    case abn
    case prod

    var trustBackend: Backend {
        switch self {
        case .dev:
            return Backend("https://www.cc-d.bit.admin.ch/trust", version: "v1")
        case .abn:
            return Backend("https://www.cc-a.bit.admin.ch/trust", version: "v1")
        case .prod:
            return Backend("https://www.cc.bit.admin.ch/trust", version: "v1")
        }
    }

    var revocationListService : Endpoint {
        return trustBackend.endpoint("revocationList")
    }

    var trustCertificatesService : Endpoint {
        return trustBackend.endpoint("keys/updates", queryParameters: ["certFormat":"IOS"])
    }

    var activeCertificatesService : Endpoint {
        return trustBackend.endpoint("keys/list")
    }
}
