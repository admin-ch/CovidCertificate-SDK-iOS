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
    let euHealthCert: EuHealthCert
    let decodedPayload :  [CBOR: CBOR]

    enum PayloadKeys: Int {
        case iss = 1
        case iat = 6
        case exp = 4
        case hcert = -260

        enum HcertKeys: Int {
            case euHealthCertV1 = 1
        }
    }
    
    func isValid(now: Date = Date()) -> Result<Bool, ValidationError> {
        if let cwtExp = decodedPayload[PayloadKeys.exp]
        {
            guard let exp = cwtExp.asNumericDate() else {
                return .failure(.SIGNATURE_TYPE_INVALID)
            }
            let expireDate = Date(timeIntervalSince1970: exp)
            if expireDate.isBefore(now) {
                return .success(false)
            }
        }
        
        if let cwtIat = decodedPayload[PayloadKeys.iat]
        {
            guard let iat = cwtIat.asNumericDate() else {
                return .failure(.SIGNATURE_TYPE_INVALID)
            }
            let issuedAt = Date(timeIntervalSince1970: Double(iat))
            if issuedAt.isAfter(now) {
                return .success(false)
            }
        }
        return .success(true)
    }

    init?(from cbor: CBOR) {
        guard let decodedPayloadCwt = cbor.decodeBytestring()?.asMap() else {
            return nil
        }
        decodedPayload = decodedPayloadCwt
        
        iss = decodedPayload[PayloadKeys.iss]?.asString()

        
        guard let hCertMap = decodedPayload[PayloadKeys.hcert]?.asMap(),
              let certData = hCertMap[PayloadKeys.HcertKeys.euHealthCertV1]?.asData(),
              let healthCert = try? CodableCBORDecoder().decode(EuHealthCert.self, from: certData) else {
            return nil
        }
        euHealthCert = healthCert
    }
}
