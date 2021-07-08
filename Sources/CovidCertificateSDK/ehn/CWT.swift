//
//  CWT.swift
//
//
//  Created by Dominik Mocher on 29.04.21.
//

import Foundation
import SwiftCBOR

struct CWT {
    let iss: String?
    let exp: CBOR?
    let iat: CBOR?
    let certificate: CovidCertificate
    let decodedPayload: [CBOR: CBOR]

    enum PayloadKeys: Int {
        case iss = 1
        case iat = 6
        case exp = 4
        case lightCert = -250
        case hcert = -260

        enum HcertKeys: Int {
            case euHealthCertV1 = 1
        }

        enum LightCertKeys: Int {
            case lightCertV1 = 1
        }
    }

    enum CWTValidationState {
        case valid
        case notYetValid
        case expired
    }

    func isValid(now: Date = Date()) -> Result<CWTValidationState, ValidationError> {
        if let cwtExp = exp {
            guard let exp = cwtExp.asNumericDate() else {
                return .failure(.SIGNATURE_TYPE_INVALID(.CWT_HEADER_PARSE_ERROR))
            }
            let expireDate = Date(timeIntervalSince1970: exp)
            if expireDate.isBefore(now) {
                return .success(.expired)
            }
        }

        if let cwtIat = iat {
            guard let iat = cwtIat.asNumericDate() else {
                return .failure(.SIGNATURE_TYPE_INVALID(.CWT_HEADER_PARSE_ERROR))
            }
            let issuedAt = Date(timeIntervalSince1970: Double(iat))
            let timeDifference = now.timeIntervalSince(issuedAt)
            // if issued at is more than 5minutes in the future consider the signature as notYetValid
            // in order to compensate for client server time skew
            if timeDifference < -5.0 * 60 {
                return .success(.notYetValid)
            }
        }
        return .success(.valid)
    }

    init?(from cbor: CBOR, type: CertificateType) {
        guard let decodedPayloadCwt = cbor.decodeBytestring()?.asMap() else {
            return nil
        }
        decodedPayload = decodedPayloadCwt

        iss = decodedPayload[PayloadKeys.iss]?.asString()
        exp = decodedPayload[PayloadKeys.exp]
        iat = decodedPayload[PayloadKeys.iat]

        switch type {
        case .dccCert:
            if let hCertMap = decodedPayload[PayloadKeys.hcert]?.asMap(),
               let certData = hCertMap[PayloadKeys.HcertKeys.euHealthCertV1]?.asData(),
               let healthCert = try? CodableCBORDecoder().decode(DCCCert.self, from: certData) {
                certificate = healthCert
            } else {
                return nil
            }
        case .lightCert:
            if let lightCertMap = decodedPayload[PayloadKeys.lightCert]?.asMap(),
               let certData = lightCertMap[PayloadKeys.LightCertKeys.lightCertV1]?.asData(),
               let healthCert = try? CodableCBORDecoder().decode(LightCert.self, from: certData) {
                certificate = healthCert
            } else {
                return nil
            }
        }
    }
}
