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

import base45_swift
import Foundation
import Gzip

public enum CovidCertError: Error, Equatable {
    case NOT_IMPLEMENTED
    case INVALID_SCHEME_PREFIX
    case BASE_45_DECODING_FAILED
    case DECOMPRESSION_FAILED
    case COSE_DESERIALIZATION_FAILED
    case HCERT_IS_INVALID

    public var errorCode: String {
        switch self {
        case .NOT_IMPLEMENTED:
            return "D|NI"
        case .INVALID_SCHEME_PREFIX:
            return "D|ISP"
        case .BASE_45_DECODING_FAILED:
            return "D|B45"
        case .DECOMPRESSION_FAILED:
            return "D|ZLB"
        case .COSE_DESERIALIZATION_FAILED:
            return "D|CDF"
        case .HCERT_IS_INVALID:
            return "D|HII"
        }
    }
}

public struct DGCHolder {
    public var healthCert: EuHealthCert {
        return cwt.euHealthCert
    }

    public var issuedAt: Date? {
        if let i = cwt.iat?.asNumericDate() {
            return Date(timeIntervalSince1970: i)
        }

        return nil
    }

    let cose: Cose
    let cwt: CWT
    public let keyId: Data

    init(cwt: CWT, cose: Cose, keyId: Data) {
        self.cwt = cwt
        self.cose = cose
        self.keyId = keyId
    }

    @available(OSX 10.13, *)
    public func hasValidSignature(for publicKey: SecKey) -> Bool {
        cose.hasValidSignature(for: publicKey)
    }
}

public struct ChCovidCert {
    private let PREFIX = "HC1:"
    private let trustList: Trustlist
    private let nationalRules = NationalRulesVerifier()

    public let environment: SDKEnvironment

    init(environment: SDKEnvironment, trustList: Trustlist) {
        self.environment = environment
        self.trustList = trustList
    }

    public func decode(encodedData: String) -> Result<DGCHolder, CovidCertError> {
        #if DEBUG
            print(encodedData)
        #endif
        guard let unprefixedEncodedString = removeScheme(prefix: PREFIX, from: encodedData) else {
            return .failure(.INVALID_SCHEME_PREFIX)
        }

        guard let decodedData = decode(unprefixedEncodedString) else {
            return .failure(.BASE_45_DECODING_FAILED)
        }

        guard let decompressedData = decompress(decodedData) else {
            return .failure(.DECOMPRESSION_FAILED)
        }

        guard let cose = cose(from: decompressedData),
              let cwt = CWT(from: cose.payload),
              let keyId = cose.keyId else {
            return .failure(.COSE_DESERIALIZATION_FAILED)
        }

        return .success(DGCHolder(cwt: cwt, cose: cose, keyId: keyId))
    }

    @available(OSX 10.13, *)
    public func checkSignature(cose: DGCHolder, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        switch cose.cwt.isValid() {
        case let .success(isValid):
            if !isValid {
                completionHandler(.failure(.CWT_EXPIRED))
                return
            }
        case let .failure(error):
            completionHandler(.failure(error))
            return
        }

        if cose.healthCert.certType == nil {
            completionHandler(.failure(.SIGNATURE_TYPE_INVALID(.CERT_TYPE_AMBIGUOUS)))
            return
        }

        trustList.key(for: cose.keyId) { result in
            switch result {
            case let .success(key):
                let isValid = cose.hasValidSignature(for: key)
                let error: ValidationError? = isValid ? nil : ValidationError.KEY_NOT_IN_TRUST_LIST
                completionHandler(.success(ValidationResult(isValid: isValid, payload: cose.healthCert, error: error)))
            case let .failure(error): completionHandler(.failure(error))
            }
        }
    }

    public func checkRevocationStatus(dgc: EuHealthCert, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        // As long as no revocation list is published yet, return true
        completionHandler(.success(ValidationResult(isValid: true, payload: dgc, error: nil)))
    }

    public func checkNationalRules(dgc: EuHealthCert, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        switch dgc.certType {
        case .vaccination:
            nationalRules.verifyVaccine(vaccine: dgc.vaccinations![0], completionHandler)
        case .recovery:
            nationalRules.verifyRecovery(recovery: dgc.pastInfections![0], completionHandler)
        case .test:
            nationalRules.verifyTest(test: dgc.tests![0], completionHandler)
        default:
            completionHandler(.failure(.NO_VALID_PRODUCT))
        }
    }

    func allRecoveriesAreValid(recoveries _: [PastInfection]) -> Bool {
        return false
    }

    /// Strips a given scheme prefix from the encoded EHN health certificate
    private func removeScheme(prefix: String, from encodedString: String) -> String? {
        guard encodedString.starts(with: prefix) else {
            return nil
        }
        return String(encodedString.dropFirst(prefix.count))
    }

    /// Base45-decodes an EHN health certificate
    private func decode(_ encodedData: String) -> Data? {
        return try? encodedData.fromBase45()
    }

    /// Decompress the EHN health certificate using ZLib
    private func decompress(_ encodedData: Data) -> Data? {
        return try? encodedData.gunzipped()
    }

    /// Creates COSE structure from EHN health certificate
    private func cose(from data: Data) -> Cose? {
        return Cose(from: data)
    }
}
