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

import CovidCertificateSDK
import Foundation

struct TestCertificateHolder: CertificateHolderType {
    let certificate: CovidCertificate

    let issuedAt: Date?

    let issuer: String?

    let expiresAt: Date?

    init(cert: DCCCert, issuedAt: Date? = nil, issuer: String = "", expiresAt: Date? = nil) {
        certificate = cert
        self.issuedAt = issuedAt
        self.issuer = issuer
        self.expiresAt = expiresAt
    }

    var keyId: Data {
        Data()
    }

    func hasValidSignature(for _: SecKey) -> Bool {
        true
    }
}
