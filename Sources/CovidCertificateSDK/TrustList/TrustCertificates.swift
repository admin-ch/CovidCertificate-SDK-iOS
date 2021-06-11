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

public class TrustCertificates: Codable, JWTExtension {
    public var certs: [TrustCertificate] = []
}

public class TrustCertificate: Codable {
    public var keyId: String
    public var use: String
    public var alg: String
    public var subjectPublicKeyInfo: String?
    public var crv: String?
    public var x: String?
    public var y: String?
}

public class ActiveTrustCertificates: Codable, JWTExtension {
    public var activeKeyIds: [String] = []
    public var validDuration: Int64
}
