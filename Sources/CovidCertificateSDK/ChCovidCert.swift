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
import JSON

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

    private let trustListManager: TrustlistManagerProtocol
    private let nationalRules = NationalRulesVerifier()

    public let environment: SDKEnvironment
    public let apiKey: String

    init(environment: SDKEnvironment, apiKey: String, trustListManager: TrustlistManagerProtocol) {
        self.environment = environment
        self.apiKey = apiKey
        self.trustListManager = trustListManager
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
    public func checkSignature(cose: DGCHolder, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
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

        trustListManager.trustCertificateUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { error in
            if let e = error?.asValidationError() {
                completionHandler(.failure(e))
            } else {
                let list = self.trustListManager.trustStorage.activeCertificatePublicKeys()
                let validationError = list.hasValidSignature(for: cose)

                completionHandler(.success(ValidationResult(isValid: validationError == nil, payload: cose.healthCert, error: validationError)))
            }
        })
    }

    public func checkRevocationStatus(dgc: EuHealthCert, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        // As long as no revocation list is published yet, return true
        trustListManager.revocationListUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { error in

            if let e = error?.asValidationError() {
                completionHandler(.failure(e))
            } else {
                let list = self.trustListManager.trustStorage.revokedCertificates()
                let isRevoked = dgc.certIdentifiers().contains { list.contains($0) }
                let error: ValidationError? = isRevoked ? .REVOKED : nil

                completionHandler(.success(ValidationResult(isValid: !isRevoked, payload: dgc, error: error)))
            }
        })
    }

    public func checkNationalRules(dgc: EuHealthCert, forceUpdate: Bool, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        switch dgc.certType {
        case .vaccination, .recovery, .test:
            trustListManager.nationalRulesListUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { error in
                if let e = error?.asNationalRulesError() {
                    completionHandler(.failure(e))
                    return
                } else {
                    let list = self.trustListManager.trustStorage.nationalRules()

                    guard let result = CertLogic(),
                          let rules = list.getRulesJSON(),
                          let valueSets = list.getValueSetsJSON() else {
                        completionHandler(.failure(.NETWORK_PARSE_ERROR))
                        return
                    }
                    if case .failure = result.updateData(rules: rules, valueSets: valueSets) {
                        completionHandler(.failure(.NETWORK_PARSE_ERROR))
                        return
                    }

                    guard let maxValidity = result.maxValidity,
                    let daysAfterFirstShot = result.daysAfterFirstShot,
                    let pcrValidity = result.pcrValidity,
                    let ratValidity = result.ratValidity else {
                        completionHandler(.failure(.NETWORK_PARSE_ERROR))
                        return
                    }

                    switch result.checkRules(hcert: dgc) {
                    case .success:
                        switch dgc.certType {
                        case .recovery:
                            completionHandler(.success(VerificationResult(isValid: true, validUntil: dgc.pastInfections?.first?.validUntilDate, validFrom: dgc.pastInfections?.first?.validUntilDate, dateError: nil)))
                        case .vaccination:

                            completionHandler(.success(VerificationResult(isValid: true, validUntil: dgc.vaccinations?.first?.getValidUntilDate(maximumValidityInDays: Int(maxValidity)), validFrom: dgc.vaccinations?.first?.getValidFromDate(daysAfterFirstShot: Int(daysAfterFirstShot)), dateError: nil)))
                        case .test:

                            completionHandler(.success(VerificationResult(isValid: true, validUntil: dgc.tests?.first?.getValidUntilDate(pcrTestValidityInHours: Int(pcrValidity), ratTestValidityInHours: Int(ratValidity)), validFrom: dgc.tests?.first?.validFromDate, dateError: nil)))
                        default:
                            completionHandler(.failure(.NETWORK_PARSE_ERROR))
                        }
                        return
                    case let .failure(.TESTS_FAILED(tests)):
                        switch tests.keys.first {
                        case "GR-CH-0001": completionHandler(.failure(.WRONG_DISEASE_TARGET))
                        case "VR-CH-0000": completionHandler(.failure(.NETWORK_PARSE_ERROR))
                        case "VR-CH-0001": completionHandler(.failure(.NOT_FULLY_PROTECTED))
                        case "VR-CH-0002": completionHandler(.failure(.NO_VALID_PRODUCT))
                        case "VR-CH-0003": completionHandler(.failure(.NO_VALID_DATE))
                        case "VR-CH-0004": completionHandler(.success(VerificationResult(isValid: false, validUntil: dgc.vaccinations?.first?.getValidUntilDate(maximumValidityInDays: Int(maxValidity)), validFrom: dgc.vaccinations?.first?.getValidFromDate(daysAfterFirstShot: Int(daysAfterFirstShot)), dateError: nil)))
                        case "VR-CH-0006": completionHandler(.success(VerificationResult(isValid: false, validUntil: dgc.vaccinations?.first?.getValidUntilDate(maximumValidityInDays: Int(maxValidity)), validFrom: dgc.vaccinations?.first?.getValidFromDate(daysAfterFirstShot: Int(daysAfterFirstShot)), dateError: nil)))
                        case "TR-CH-0000": completionHandler(.failure(.NETWORK_PARSE_ERROR))
                        case "TR-CH-0001": completionHandler(.failure(.POSITIVE_RESULT))
                        case "TR-CH-0002": completionHandler(.failure(.WRONG_TEST_TYPE))
                        case "TR-CH-0003": completionHandler(.failure(.NO_VALID_PRODUCT))
                        case "TR-CH-0004": completionHandler(.failure(.NO_VALID_DATE))
                        case "TR-CH-0005": completionHandler(.success(VerificationResult(isValid: false, validUntil: dgc.tests?.first?.getValidUntilDate(pcrTestValidityInHours: Int(pcrValidity), ratTestValidityInHours: Int(ratValidity)), validFrom: dgc.tests?.first?.validFromDate, dateError: nil)))
                        case "TR-CH-0006": completionHandler(.success(VerificationResult(isValid: false, validUntil: dgc.tests?.first?.getValidUntilDate(pcrTestValidityInHours: Int(pcrValidity), ratTestValidityInHours: Int(ratValidity)), validFrom: dgc.tests?.first?.validFromDate, dateError: nil)))
                        case "TR-CH-0007": completionHandler(.success(VerificationResult(isValid: false, validUntil: dgc.tests?.first?.getValidUntilDate(pcrTestValidityInHours: Int(pcrValidity), ratTestValidityInHours: Int(ratValidity)), validFrom: dgc.tests?.first?.validFromDate, dateError: nil)))
                        case "RR-CH-0000": completionHandler(.failure(.NETWORK_PARSE_ERROR))
                        case "RR-CH-0001": completionHandler(.failure(.NO_VALID_DATE))
                        case "RR-CH-0002": completionHandler(.success(VerificationResult(isValid: false, validUntil: dgc.pastInfections?.first?.validUntilDate, validFrom: dgc.pastInfections?.first?.validUntilDate, dateError: nil)))
                        case "RR-CH-0003": completionHandler(.success(VerificationResult(isValid: false, validUntil: dgc.pastInfections?.first?.validUntilDate, validFrom: dgc.pastInfections?.first?.validUntilDate, dateError: nil)))
                        default:
                            completionHandler(.failure(.UNKNOWN_TEST_FAILURE))
                        }
                        return
                    case let .failure(.TEST_COULD_NOT_BE_PERFORMED(test)):
                        completionHandler(.failure(.UNKNOWN_TEST_FAILURE))
                        return
                    default:
                        completionHandler(.failure(.NO_VALID_DATE))
                        return
                    }
                }
            })
        default:
            completionHandler(.failure(.NO_VALID_PRODUCT))
        }
    }

    public func restartTrustListUpdate(completionHandler: @escaping () -> Void, updateTimeInterval: TimeInterval) {
        trustListManager.restartTrustListUpdate(completionHandler: completionHandler, updateTimeInterval: updateTimeInterval)
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
