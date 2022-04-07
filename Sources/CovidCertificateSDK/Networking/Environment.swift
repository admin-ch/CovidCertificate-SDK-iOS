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

    public static let applicationJwtPlusJws: String = "application/json+jws"

    func revocationListService(since: String?) -> Endpoint {
        var queryParameters: [String: String]?

        if let since = since {
            queryParameters = ["since": since]
        }

        return trustBackend.endpoint("revocationList",
                                     queryParameters: queryParameters,
                                     headers: ["Accept": SDKEnvironment.applicationJwtPlusJws],
                                     overwriteVersion: "v2")
    }

    var nationalRulesListService: Endpoint {
        trustBackend.endpoint("verificationRules", headers: ["Accept": SDKEnvironment.applicationJwtPlusJws], overwriteVersion: "v2")
    }

    func foreignRulesListService(countryCode: String) -> Endpoint {
        trustBackend.endpoint("foreignRules/\(countryCode)",
                              headers: ["Accept": SDKEnvironment.applicationJwtPlusJws],
                              overwriteVersion: "v2")
    }

    func foreignCountryCodesService() -> Endpoint {
        trustBackend.endpoint("foreignRules",
                              headers: ["Accept": SDKEnvironment.applicationJwtPlusJws],
                              overwriteVersion: "v2")
    }

    func trustCertificatesService(since: String, upTo: String) -> Endpoint {
        trustBackend.endpoint("keys/updates",
                              queryParameters: ["certFormat": "IOS",
                                                "since": since,
                                                "upTo": upTo],
                              headers: ["Accept": SDKEnvironment.applicationJwtPlusJws],
                              overwriteVersion: "v2")
    }

    var activeCertificatesService: Endpoint {
        trustBackend.endpoint("keys/list", headers: ["Accept": SDKEnvironment.applicationJwtPlusJws], overwriteVersion: "v2")
    }

    func metadata() -> Endpoint {
        trustBackend.endpoint("metadata", headers: ["Accept": SDKEnvironment.applicationJwtPlusJws])
    }
}
