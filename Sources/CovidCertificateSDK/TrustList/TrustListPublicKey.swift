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
import Security

class TrustListPublicKey {
    // MARK: - Elements

    let keyId: String
    let key: SecKey

    // MARK: - Used with RSA

    init?(keyId: String, withRsaKey rsaKey: String?) {
        let attributes: [CFString: Any] = [kSecAttrKeyClass: kSecAttrKeyClassPublic,
                                           kSecAttrKeyType: kSecAttrKeyTypeRSA,
                                           kSecAttrKeySizeInBits: 2048]

        guard let rsaKey = rsaKey,
              let data = Data(base64Encoded: rsaKey),
              let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, nil) else {
            return nil
        }

        self.key = key
        self.keyId = keyId
    }

    // MARK: - Used with EC

    init?(keyId: String, withX x: String?, andY y: String?) {
        let attributes: [CFString: Any] = [kSecAttrKeyClass: kSecAttrKeyClassPublic,
                                           kSecAttrKeyType: kSecAttrKeyTypeEC]

        guard let x = x, let y = y,
              let xData = Data(base64Encoded: x),
              let yData = Data(base64Encoded: y),
              let key = SecKeyCreateWithData(Data([0x4] + xData + yData) as CFData, attributes as CFDictionary, nil) else {
            return nil
        }

        self.key = key
        self.keyId = keyId
    }
}

extension Array where Element == TrustListPublicKey {
    func hasValidSignature(for holder: DGCHolder) -> ValidationError? {
        let filteredList = filter { $0.keyId == holder.keyId.base64EncodedString() }

        guard filteredList.count > 0 else {
            return ValidationError.KEY_NOT_IN_TRUST_LIST
        }

        let isValid = filteredList.contains { t in holder.hasValidSignature(for: t.key) }

        guard isValid else {
            return ValidationError.KEY_NOT_IN_TRUST_LIST
        }

        return nil
    }
}
