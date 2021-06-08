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
import SwiftCBOR

protocol Trustlist {
    func publicKeys() -> [TrustListPublicKey]
    func key(for keyId: Data, completionHandler: @escaping (Result<SecKey, ValidationError>) -> Void)
}

class StaticTrustlist : Trustlist {
    // Public keys of Swiss DSCs environment (ASN1 Format)
    private let DEV_RSA_ASN1_DER = "MIIBCgKCAQEA4uZO4/7tneZ3XD5OAiTyoANOohQZC+DzZ4YC0AoLnEO+Z3PcTialCuRKS1zHfujNPI0GGG09DRVVXdv+tcKNXFDt/nRU1zlWDGFf4/63l5RIjkWFD3JFKqR8IlcJjrYYxstuZs3May3SGQJ+kZaeH5GFZMRvE0waHqMxbfwakvjf8qyBXCrZ1WsK+XJf7iYbJS2dO1a5HnegxPuRA7Zz8ikO7QRzmSongqOlkejEaIkFjx7gLGTUsOrBPYa5sdZqinDwmnjtKi52HLWarMXs+t1MN4etIp7GE7/zarjBNxk1Efiiwl+RdcwJ2uVwfrgzxfv3/TekZF8IUykV2Geu3QIDAQAB"
    private let ABN_RSA_ASN1_DER = "MIIBCgKCAQEA0bVecdVEUBEaB6Uu8VtXrtVnN0Fa9+hAcO0XcjLgLVDB89Y4+huGO94Y93TY43x9eXRRWcNleacBR0OdzDpAUOfdUbvrw2nNSb5OhhKG+mHbuBaImWKpvima0BeK0Gid01IG8u83SKBOabU34WUn5m37mPj0YonqFOyjnyCE1wrnaeG95lh0ZC5WCUB2BqNI4ZZQXwDCCC5STka3l02ZNAIHMoHLmgqAqWbXXS5r41ltumbRRaVGu47pSURpzz/wCZep6HnmhNvOE/T5lNzlolxgcltKc7VZtcoZnK9JFkT7tk4GR2H4mnA1lxAHOkJOaEkZxT6Nrm5r8OvA0ybuMQIDAQAB"
    private let PROD_RSA_ASN1_DER = "MIIBCgKCAQEAtk/51stJXU48RqD2lh4IdsxFrjlJfmTCrLr3cQNEXkrEoI3OEV8NnotE1RjVmQrqLTT04oxpWlcbMolXtJBtu3rOiLNwQvyVEbj/xSc6KT84Tp7GBo1P/kkunY+Vmab6HUCV/oGZYmsdiUP/OnTPX6Wy6delDhnrgHIDti73/TSsG7Zl1V6km7+KIkjAkVCEDkkUD7uffd4G+GBZ0B9F1KOT0IcFQNvDm0zlROVoGFlmPS8DWlrLHuIdMbB281uiDjcN+kNUt7rUyyj6TFgX9WCgEB/5mQBMRaaXK1zeDTaNkmC2S7IWxhMQsMBXJyAdbD9AnQOZc6XRjBauO7gz0wIDAQAB"
    
    func publicKeys() -> [TrustListPublicKey] {
        switch CovidCertificateSDK.currentEnvironment {
        case .dev:
            return [TrustListPublicKey(keyId: "mmrfzpMU6xc=", withRsaKey: DEV_RSA_ASN1_DER)].compactMap{ $0 }
        case .abn:
            return [TrustListPublicKey(keyId: "JLxre3vSwyg=", withRsaKey: ABN_RSA_ASN1_DER)].compactMap{ $0 }
        case .prod:
            return [TrustListPublicKey(keyId: "Ll3NP03zOxY=", withRsaKey: PROD_RSA_ASN1_DER)].compactMap{ $0 }
        }
    }

    // for now we hardcode the key so we don't need a jwks list
    func key(for keyId: Data, completionHandler: @escaping (Result<SecKey, ValidationError>) -> Void) {
        guard let publicKey = publicKeys().first(where: { key in
            key.keyId == keyId.base64EncodedString()
        }) else {
            completionHandler(.failure(.KEY_NOT_IN_TRUST_LIST))
            return
        }

        completionHandler(.success(publicKey.key))
    }
}

class TrustListPublicKey {
    init?(keyId: String, withRsaKey rsaKey: String) {
        let attributes: [CFString: Any] = [kSecAttrKeyClass: kSecAttrKeyClassPublic,
                                           kSecAttrKeyType: kSecAttrKeyTypeRSA,
                                           kSecAttrKeySizeInBits: 2048]

        guard let data = Data(base64Encoded: rsaKey),
              let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, nil) else {
            return nil
        }

        self.key = key
        self.keyId = keyId
    }

    init?(keyId: String, withX x: String, andY y: String) {
        let attributes: [CFString: Any] = [kSecAttrKeyClass: kSecAttrKeyClassPublic,
                                           kSecAttrKeyType: kSecAttrKeyTypeEC]

        guard let xData = Data(base64Encoded: x),
              let yData = Data(base64Encoded: y),
              let key = SecKeyCreateWithData(Data([0x4] + xData + yData) as CFData, attributes as CFDictionary, nil) else {
            return nil
        }

        self.key = key
        self.keyId = keyId
    }
    
    let keyId : String
    let key: SecKey
}
