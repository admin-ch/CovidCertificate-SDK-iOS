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

/// Main class for handling SDK logic
struct CovidCertificateImpl {
    private let trustListManager: TrustlistManagerProtocol

    private let metadataManager = MetadataManager()

    let environment: SDKEnvironment

    let apiKey: String

    init(environment: SDKEnvironment, apiKey: String, trustListManager: TrustlistManagerProtocol) {
        self.environment = environment
        self.apiKey = apiKey
        self.trustListManager = trustListManager
    }

    func decode(encodedData: String) -> Result<CertificateHolder, CovidCertError> {
        #if DEBUG
            print(encodedData)
        #endif

        guard let type = getType(from: encodedData),
              let unprefixedEncodedString = removeScheme(prefix: type.prefix, from: encodedData) else {
            return .failure(.INVALID_SCHEME_PREFIX)
        }

        guard let decodedData = decode(unprefixedEncodedString) else {
            return .failure(.BASE_45_DECODING_FAILED)
        }

        guard let decompressedData = decompress(decodedData) else {
            return .failure(.DECOMPRESSION_FAILED)
        }

        guard let cose = cose(from: decompressedData),
              let cwt = CWT(from: cose.payload, type: type),
              let keyId = cose.keyId else {
            return .failure(.COSE_DESERIALIZATION_FAILED)
        }

        return .success(CertificateHolder(cwt: cwt, cose: cose, keyId: keyId))
    }

    func check(holder: CertificateHolder, forceUpdate: Bool, _ completionHandler: @escaping (CheckResults) -> Void) {
        let group = DispatchGroup()

        var signatureResult: Result<ValidationResult, ValidationError>?
        var revocationStatusResult: Result<ValidationResult, ValidationError>?
        var nationalRulesResult: Result<VerificationResult, NationalRulesError>?

        group.enter()
        checkSignature(holder: holder, forceUpdate: forceUpdate) { result in
            signatureResult = result
            group.leave()
        }

        switch holder.certificate {
        case let certificate as DCCCert:
            group.enter()
            checkRevocationStatus(certificate: certificate, forceUpdate: forceUpdate) { result in
                revocationStatusResult = result
                group.leave()
            }

            group.enter()
            checkNationalRules(holder: holder, forceUpdate: forceUpdate) { result in
                nationalRulesResult = result
                group.leave()
            }
        case is LightCert:
            // Skip revocation check for light certificates
            revocationStatusResult = nil

            // a light certificate is not valid if the CWT has expired
            // all other CWT invalid cases are already handled in the signature check
            var isValid = true
            switch holder.cwt.isValid() {
            case .success(.expired):
                isValid = false
            default:
                break
            }

            nationalRulesResult = .success(.init(isValid: isValid,
                                                 validUntil: holder.expiresAt,
                                                 validFrom: holder.issuedAt,
                                                 dateError: nil,
                                                 isSwitzerlandOnly: true))
        default:
            fatalError("Unsupported Certificate type")
        }

        group.notify(queue: .main) {
            guard let signatureResult = signatureResult,
                  let nationalRulesResult = nationalRulesResult else {
                assertionFailure()
                return
            }

            completionHandler(.init(signature: signatureResult,
                                    revocationStatus: revocationStatusResult,
                                    nationalRules: nationalRulesResult))
        }
    }

    func checkSignature(holder: CertificateHolder, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        switch holder.certificate {
        case let certificate as DCCCert:
            if certificate.immunisationType == nil {
                completionHandler(.failure(.SIGNATURE_TYPE_INVALID(.CERT_TYPE_AMBIGUOUS)))
                return
            }
        default:
            break
        }

        trustListManager.trustCertificateUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { lastError in

            if case .NETWORK_SERVER_ERROR = lastError {
                // Only continue with cached trust list for NETWORK_SERVER_ERRORS (HTTP status != 200)
            } else if let e = lastError?.asValidationError() {
                completionHandler(.failure(e))
                return
            }
            
            // Safe-guard that we have a recent trust list available at this point
            guard trustListManager.trustStorage.certificateListIsValid() else {
                if let e = lastError?.asValidationError() {
                    // If available, return specific last (networking) error
                    completionHandler(.failure(e))
                } else {
                    // Otherwise generic offline error
                    completionHandler(.failure(ValidationError.NETWORK_NO_INTERNET_CONNECTION(errorCode: "")))
                }
                return
            }

            let list = self.trustListManager.trustStorage.activeCertificatePublicKeys(useFilters: holder.certificate.type.trustListUseFilters)
            let validationError = list.hasValidSignature(for: holder)

            // if there is a signature error we return it before checking the cwt validity
            if let error = validationError {
                completionHandler(.success(ValidationResult(isValid: false, payload: holder.certificate, error: error)))
                return
            }

            switch holder.cwt.isValid() {
            case let .success(cwtValidation):
                switch cwtValidation {
                case .valid:
                    break
                case .expired:
                    completionHandler(.failure(.CWT_EXPIRED))
                    return
                case .notYetValid:
                    completionHandler(.failure(.CWT_NOT_YET_VALID))
                    return
                }
            case let .failure(error):
                completionHandler(.failure(error))
                return
            }

            completionHandler(.success(ValidationResult(isValid: true, payload: holder.certificate, error: nil)))
        })
    }

    func checkRevocationStatus(certificate: DCCCert, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        trustListManager.revocationListUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { lastError in
            
            if case .NETWORK_SERVER_ERROR = lastError {
                // Only continue with cached trust list for NETWORK_SERVER_ERRORS (HTTP status != 200)
            } else if let e = lastError?.asValidationError() {
                completionHandler(.failure(e))
                return
            }

            // Safe-guard that we have a recent revocation list available at this point
            guard trustListManager.trustStorage.revocationListIsValid() else {
                if let e = lastError?.asValidationError() {
                    // If available, return specific last (networking) error
                    completionHandler(.failure(e))
                } else {
                    // Otherwise generic offline error
                    completionHandler(.failure(ValidationError.NETWORK_NO_INTERNET_CONNECTION(errorCode: "")))
                }
                return
            }

            let list = self.trustListManager.trustStorage.revokedCertificates()
            let isRevoked = certificate.certIdentifiers().contains { list.contains($0) }
            let error: ValidationError? = isRevoked ? .REVOKED : nil

            completionHandler(.success(ValidationResult(isValid: !isRevoked, payload: certificate, error: error)))
        })
    }

    func checkNationalRules(holder: CertificateHolderType, forceUpdate: Bool, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        guard let certificate = holder.certificate as? DCCCert else {
            completionHandler(.failure(.UNKNOWN_CERTLOGIC_FAILURE))
            return
        }

        if certificate.immunisationType == nil {
            completionHandler(.failure(.NO_VALID_PRODUCT))
            return
        }

        trustListManager.nationalRulesListUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { lastError in
            
            if case .NETWORK_SERVER_ERROR = lastError {
                // Only continue with cached trust list for NETWORK_SERVER_ERRORS (HTTP status != 200)
            } else if let e = lastError?.asNationalRulesError() {
                completionHandler(.failure(e))
                return
            }

            // Safe-guard that we have a recent national rules list available at this point
            guard trustListManager.trustStorage.nationalRulesListIsStillValid() else {
                if let e = lastError?.asNationalRulesError() {
                    // If available, return specific last (networking) error
                    completionHandler(.failure(e))
                } else {
                    // Otherwise generic offline error
                    completionHandler(.failure(NationalRulesError.NETWORK_NO_INTERNET_CONNECTION(errorCode: "")))
                }
                return
            }

            let list = self.trustListManager.trustStorage.nationalRules()

            guard let certLogic = CertLogic(),
                  let valueSets = list.valueSets,
                  let rules = list.rules,
                  let displayRules = list.displayRules
            else {
                completionHandler(.failure(.NETWORK_PARSE_ERROR))
                return
            }

            if case .failure = certLogic.updateData(rules: rules, valueSets: valueSets, displayRules: displayRules) {
                completionHandler(.failure(.NETWORK_PARSE_ERROR))
                return
            }

            let displayRulesResult = try? certLogic.checkDisplayRules(holder: holder).get()

            switch certLogic.checkRules(hcert: certificate) {
            case .success:
                completionHandler(.success(VerificationResult(isValid: true,
                                                              validUntil: displayRulesResult?.validUntil,
                                                              validFrom: displayRulesResult?.validFrom,
                                                              dateError: nil,
                                                              isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                return
            case let .failure(.TESTS_FAILED(tests)):
                switch tests.keys.first {
                case "GR-CH-0001": completionHandler(.failure(.WRONG_DISEASE_TARGET))
                case "VR-CH-0000": completionHandler(.failure(.TOO_MANY_VACCINE_ENTRIES))
                case "VR-CH-0001": completionHandler(.failure(.NOT_FULLY_PROTECTED))
                case "VR-CH-0002": completionHandler(.failure(.NO_VALID_PRODUCT))
                case "VR-CH-0003": completionHandler(.failure(.NO_VALID_DATE))
                case "VR-CH-0004":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .NOT_YET_VALID,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "VR-CH-0005":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .NOT_YET_VALID,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "VR-CH-0006":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .EXPIRED,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "VR-CH-0007":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .EXPIRED,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "VR-CH-0008":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .EXPIRED,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "TR-CH-0000": completionHandler(.failure(.TOO_MANY_TEST_ENTRIES))
                case "TR-CH-0001": completionHandler(.failure(.POSITIVE_RESULT))
                case "TR-CH-0002": completionHandler(.failure(.WRONG_TEST_TYPE))
                case "TR-CH-0003": completionHandler(.failure(.NO_VALID_PRODUCT))
                case "TR-CH-0004": completionHandler(.failure(.NO_VALID_DATE))
                case "TR-CH-0005":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .NOT_YET_VALID,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "TR-CH-0006":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .EXPIRED,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "TR-CH-0007":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .EXPIRED,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "TR-CH-0008":
                    completionHandler(.failure(.NEGATIVE_RESULT))
                case "TR-CH-0009":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .EXPIRED,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "RR-CH-0000": completionHandler(.failure(.TOO_MANY_RECOVERY_ENTRIES))
                case "RR-CH-0001": completionHandler(.failure(.NO_VALID_DATE))
                case "RR-CH-0002":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .NOT_YET_VALID,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                case "RR-CH-0003":
                    completionHandler(.success(VerificationResult(isValid: false,
                                                                  validUntil: displayRulesResult?.validUntil,
                                                                  validFrom: displayRulesResult?.validFrom,
                                                                  dateError: .EXPIRED,
                                                                  isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly)))
                default:
                    completionHandler(.failure(.UNKNOWN_CERTLOGIC_FAILURE))
                }
                return
            case .failure(.TEST_COULD_NOT_BE_PERFORMED(_)):
                completionHandler(.failure(.UNKNOWN_CERTLOGIC_FAILURE))
                return
            default:
                completionHandler(.failure(.NO_VALID_DATE))
                return
            }
        })
    }

    func restartTrustListUpdate(completionHandler: @escaping () -> Void, updateTimeInterval: TimeInterval) {
        trustListManager.restartTrustListUpdate(completionHandler: completionHandler, updateTimeInterval: updateTimeInterval)
    }

    func updateMetadata() {
        metadataManager.load()
    }

    func allRecoveriesAreValid(recoveries _: [PastInfection]) -> Bool {
        false
    }

    /// Strips a given scheme prefix from the encoded EHN health certificate
    func removeScheme(prefix: String, from encodedString: String) -> String? {
        guard encodedString.starts(with: prefix) else {
            return nil
        }
        return String(encodedString.dropFirst(prefix.count))
    }

    func getType(from string: String) -> CertificateType? {
        for type in CertificateType.allCases {
            if string.starts(with: type.prefix) {
                return type
            }
        }
        return nil
    }

    /// Base45-decodes an EHN health certificate
    func decode(_ encodedData: String) -> Data? {
        try? encodedData.fromBase45()
    }

    /// Decompress the EHN health certificate using ZLib
    func decompress(_ encodedData: Data) -> Data? {
        try? encodedData.gunzipped()
    }

    /// Creates COSE structure from EHN health certificate
    func cose(from data: Data) -> Cose? {
        Cose(from: data)
    }
}
