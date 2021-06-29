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
}

class ActiveTrustCertificates: Codable, JWTExtension {
    var activeKeyIds: [String] = []
    var validDuration: Int64
}
