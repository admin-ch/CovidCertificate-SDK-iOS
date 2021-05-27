//
//  CWT.swift
//
//
//  Created by Dominik Mocher on 29.04.21.
//

import Foundation
import SwiftCBOR

public struct CWT {
    let iss: String?
    let exp: UInt64?
    let iat: UInt64?
    let euHealthCert: EuHealthCert

    enum PayloadKeys: Int {
        case iss = 1
        case iat = 6
        case exp = 4
        case hcert = -260

        enum HcertKeys: Int {
            case euHealthCertV1 = 1
        }
    }

    init?(from cbor: CBOR) {
        guard let decodedPayload = cbor.decodeBytestring()?.asMap() else {
            return nil
        }
        iss = decodedPayload[PayloadKeys.iss]?.asString()
        exp = decodedPayload[PayloadKeys.exp]?.asUInt64()
        iat = decodedPayload[PayloadKeys.iat]?.asUInt64()
        guard let hCertMap = decodedPayload[PayloadKeys.hcert]?.asMap(),
              let certData = hCertMap[PayloadKeys.HcertKeys.euHealthCertV1]?.asData(),
              let healthCert = try? CodableCBORDecoder().decode(EuHealthCert.self, from: certData) else {
            return nil
        }
        euHealthCert = healthCert
    }
}
