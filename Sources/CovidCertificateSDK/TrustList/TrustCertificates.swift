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

class TrustCertificates: Codable, JWTExtension {
    var certs: [TrustCertificate] = []
}

class TrustCertificate: Codable {
    var keyId: String
    var use: String
    var alg: String
    var subjectPublicKeyInfo: String?
    var crv: String?
    var x: String?
    var y: String?

    lazy var trustListPublicKey: TrustListPublicKey? = {
        if alg == "RS256" {
            return TrustListPublicKey(keyId: keyId, withRsaKey: subjectPublicKeyInfo)
        } else if alg == "ES256" {
            return TrustListPublicKey(keyId: keyId, withX: x, andY: y)
        } else {
            return nil
        }
    }()

    enum CodingKeys: String, CodingKey {
        case keyId
        case use
        case alg
        case subjectPublicKeyInfo
        case crv
        case x
        case y
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyId = try container.decode(String.self, forKey: .keyId)
        use = try container.decode(String.self, forKey: .use)
        alg = try container.decode(String.self, forKey: .alg)
        subjectPublicKeyInfo = try container.decode(String.self, forKey: .subjectPublicKeyInfo)
        crv = try container.decode(String.self, forKey: .crv)
        x = try container.decode(String.self, forKey: .x)
        y = try container.decode(String.self, forKey: .y)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyId, forKey: .keyId)
        try container.encode(use, forKey: .use)
        try container.encode(alg, forKey: .alg)
        try container.encode(subjectPublicKeyInfo, forKey: .subjectPublicKeyInfo)
        try container.encode(crv, forKey: .crv)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

class ActiveTrustCertificates: Codable, JWTExtension {
    var activeKeyIds: [String] = []
    var validDuration: Int64
    var upTo: Int64?
}

extension TrustCertificate {
    func containsUse(trustListUseFilters: [String]) -> Bool {
        trustListUseFilters.contains(where: { use.contains($0) })
    }
}

extension Array where Element == TrustCertificate {
    func hasValidSignature(for holder: CertificateHolder) -> ValidationError? {
        let filteredList = filter { $0.keyId == holder.keyId.base64EncodedString() &&
            $0.containsUse(trustListUseFilters: holder.certificate.type.trustListUseFilters)
        }

        guard filteredList.count > 0 else {
            return ValidationError.KEY_NOT_IN_TRUST_LIST
        }

        let isValid = filteredList.contains { t in
            guard let trustListPublicKey = t.trustListPublicKey else { return false }
            return holder.hasValidSignature(for: trustListPublicKey.key)
        }

        guard isValid else {
            return ValidationError.KEY_NOT_IN_TRUST_LIST
        }

        return nil
    }
}
