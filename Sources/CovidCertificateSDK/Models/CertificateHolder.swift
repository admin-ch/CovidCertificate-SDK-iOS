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

public struct CertificateHolder {
    let cose: Cose
    let cwt: CWT
    public let keyId: Data

    init(cwt: CWT, cose: Cose, keyId: Data) {
        self.cwt = cwt
        self.cose = cose
        self.keyId = keyId
    }

    public var certificate: CovidCertificate {
        cwt.certificate
    }

    public var issuedAt: Date? {
        if let i = cwt.iat?.asNumericDate() {
            return Date(timeIntervalSince1970: i)
        }

        return nil
    }

    public var issuer: String? {
        cwt.iss
    }

    var expiresAt: Date? {
        if let i = cwt.exp?.asNumericDate() {
            return Date(timeIntervalSince1970: i)
        }
        return nil
    }

    public func hasValidSignature(for publicKey: SecKey) -> Bool {
        cose.hasValidSignature(for: publicKey)
    }
}
