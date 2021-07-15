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
        let version = "v1"
        switch self {
        case .dev:
            return Backend("https://www.cc-d.bit.admin.ch/trust", version: version)
        case .abn:
            return Backend("https://www.cc-a.bit.admin.ch/trust", version: version)
        case .prod:
            return Backend("https://www.cc.bit.admin.ch/trust", version: version)
        }
    }

    public static let applicationJwtPlusJws: String = "application/json+jws"

    var revocationListService: Endpoint {
        return trustBackend.endpoint("revocationList", headers: ["Accept": SDKEnvironment.applicationJwtPlusJws])
    }

    var nationalRulesListService: Endpoint {
        return trustBackend.endpoint("verificationRules", headers: ["Accept": SDKEnvironment.applicationJwtPlusJws])
    }

    func trustCertificatesService(since: String, upTo: String) -> Endpoint {
        return trustBackend.endpoint("keys/updates",
                                     queryParameters: ["certFormat": "IOS",
                                                       "since": since,
                                                       "upTo": upTo],
                                     headers: ["Accept": SDKEnvironment.applicationJwtPlusJws],
                                     overwriteVersion: "v2")
    }

    var activeCertificatesService: Endpoint {
        return trustBackend.endpoint("keys/list", headers: ["Accept": SDKEnvironment.applicationJwtPlusJws], overwriteVersion: "v2")
    }

    func metadata() -> Endpoint {
        return trustBackend.endpoint("metadata", headers: ["Accept": SDKEnvironment.applicationJwtPlusJws])
    }
}
