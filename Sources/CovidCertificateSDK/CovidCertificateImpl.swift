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

    var options: SDKOptions?

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

    func check(holder: CertificateHolder, forceUpdate: Bool, modes: [CheckMode], useBloomFilter: Bool, _ completionHandler: @escaping (CheckResults) -> Void) {
        let group = DispatchGroup()

        var signatureResult: Result<ValidationResult, ValidationError>?
        var revocationStatusResult: Result<ValidationResult, ValidationError>?
        var nationalRulesResult: CheckRulesResult?

        group.enter()
        checkSignature(holder: holder, forceUpdate: forceUpdate) { result in
            signatureResult = result
            group.leave()
        }

        group.enter()
        checkNationalRules(holder: holder, forceUpdate: forceUpdate, modes: modes) { result in
            nationalRulesResult = result
            group.leave()
        }

        switch holder.certificate {
        case let certificate as DCCCert:
            group.enter()
            if useBloomFilter {
                checkRevocationStatusVerifier(certificate: certificate, forceUpdate: forceUpdate) { result in
                    revocationStatusResult = result
                    group.leave()
                }
            } else {
                checkRevocationStatusWallet(holder: holder, forceUpdate: forceUpdate) { result in
                    revocationStatusResult = result
                    group.leave()
                }
            }
        case is LightCert:
            // Skip revocation check for light certificates
            revocationStatusResult = nil
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
                                    nationalRules: nationalRulesResult.nationalRules,
                                    modeResults: nationalRulesResult.modeResults))
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

            if options?.timeshiftDetectionEnabled ?? false {
                if case .NETWORK_SERVER_ERROR = lastError {
                    // Only continue with cached revocation list for NETWORK_SERVER_ERRORS (HTTP status != 200)
                } else if let e = lastError?.asValidationError() {
                    completionHandler(.failure(e))
                    return
                }
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

            let list = self.trustListManager.trustStorage.activeCertificatePublicKeys()
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

    func checkRevocationStatusVerifier(certificate: DCCCert, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        trustListManager.revocationListUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { lastError in

            if options?.timeshiftDetectionEnabled ?? false {
                if case .NETWORK_SERVER_ERROR = lastError {
                    // Only continue with cached revocation list for NETWORK_SERVER_ERRORS (HTTP status != 200)
                } else if let e = lastError?.asValidationError() {
                    completionHandler(.failure(e))
                    return
                }
            }
            
            //TODO: DE Here we have to check if bloomfilter of certificate is already in DB
            //TODO: DE If bloomfilter of cert in DB: check if bloomfilter valid && no hit -> certificate is not revoked
            //TODO: DE If bloomfilter not in DB or bloomfilter in DB but bloomfilter invalid -> Get bloomfilter

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
    
    func checkRevocationStatusWallet(holder: CertificateHolder, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        guard let certificate = holder.certificate as? DCCCert else {
            completionHandler(.failure(ValidationError.GENERAL_ERROR))
            return
        }
        
        trustListManager.revocationListUpdater.addCheckOperation(for: certificate, forceUpdate: forceUpdate, checkOperation: { lastError in

            if options?.timeshiftDetectionEnabled ?? false {
                if case .NETWORK_SERVER_ERROR = lastError {
                    // Only continue with cached revocation list for NETWORK_SERVER_ERRORS (HTTP status != 200)
                } else if let e = lastError?.asValidationError() {
                    completionHandler(.failure(e))
                    return
                }
            }
            
            /*TODO: DE We first check if we already have a list of hashes saved for the 'certificate'
              TODO: DE If there is already one saved and it's valid we can check if the 'certificate' is in this list, if not -> done, not revoked
              TODO: DE If there is not already one saved or it's expired, we request the hashes for all revoked certificates with matching kid&prefix -> check in there if it's valid or not
             */
            
            guard trustListManager.trustStorage.revocationCertIsValid(for: holder) else {
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

    internal struct CheckRulesResult {
        var nationalRules: Result<VerificationResult, NationalRulesError> = .failure(.NETWORK_PARSE_ERROR)
        var modeResults: ModeResults = .init(results: [:])
    }

    func checkNationalRules(holder: CertificateHolderType,
                            forceUpdate: Bool,
                            modes: [CheckMode],
                            _ completionHandler: @escaping (CheckRulesResult) -> Void) {
        var result = CheckRulesResult()
        var modeResults: [CheckMode: Result<ModeCheckResult, NationalRulesError>] = [:]

        trustListManager.nationalRulesListUpdater.addCheckOperation(forceUpdate: forceUpdate, checkOperation: { lastError in

            if options?.timeshiftDetectionEnabled ?? false {
                if case .NETWORK_SERVER_ERROR = lastError {
                    // Only continue with cached revocation list for NETWORK_SERVER_ERRORS (HTTP status != 200)
                } else if let e = lastError?.asNationalRulesError() {
                    result.nationalRules = .failure(e)
                    for mode in modes {
                        modeResults[mode] = .failure(e)
                    }
                    result.modeResults = .init(results: modeResults)
                    completionHandler(result)
                    return
                }
            }

            // Safe-guard that we have a recent national rules list available at this point
            guard trustListManager.trustStorage.nationalRulesListIsStillValid() else {
                if let e = lastError?.asNationalRulesError() {
                    // If available, return specific last (networking) error
                    result.nationalRules = .failure(e)
                    for mode in modes {
                        modeResults[mode] = .failure(e)
                    }
                    result.modeResults = .init(results: modeResults)
                    completionHandler(result)
                } else {
                    // Otherwise generic offline error
                    result.nationalRules = .failure(NationalRulesError.NETWORK_NO_INTERNET_CONNECTION(errorCode: ""))
                    for mode in modes {
                        modeResults[mode] = .failure(NationalRulesError.NETWORK_NO_INTERNET_CONNECTION(errorCode: ""))
                    }
                    result.modeResults = .init(results: modeResults)
                    completionHandler(result)
                }
                return
            }

            let list = self.trustListManager.trustStorage.nationalRules()

            guard let certLogic = CertLogic(),
                  let valueSets = list.valueSets,
                  let rules = list.rules,
                  let displayRules = list.displayRules
            else {
                result.nationalRules = .failure(.NETWORK_PARSE_ERROR)
                for mode in modes {
                    modeResults[mode] = .failure(.NETWORK_PARSE_ERROR)
                }
                result.modeResults = .init(results: modeResults)
                completionHandler(result)
                return
            }

            let modeRule = list.modeRules.logic

            if case .failure = certLogic.updateData(rules: rules,
                                                    valueSets: valueSets,
                                                    displayRules: displayRules,
                                                    modeRule: modeRule) {
                result.nationalRules = .failure(.NETWORK_PARSE_ERROR)
                for mode in modes {
                    modeResults[mode] = .failure(.NETWORK_PARSE_ERROR)
                }
                result.modeResults = .init(results: modeResults)
                completionHandler(result)
                return
            }

            for (mode, modeResult) in certLogic.checkModeRules(holder: holder, modes: modes) {
                switch modeResult {
                case let .success(modeResult):
                    modeResults[mode] = .success(modeResult)
                case .failure(.TEST_COULD_NOT_BE_PERFORMED(_)):
                    modeResults[mode] = .failure(.UNKNOWN_CERTLOGIC_FAILURE)
                case .failure:
                    modeResults[mode] = .failure(.NETWORK_PARSE_ERROR)
                }
            }
            result.modeResults = .init(results: modeResults)

            guard let certificate = holder.certificate as? DCCCert else {
                // a light certificate is not valid if the CWT has expired
                // all other CWT invalid cases are already handled in the signature check
                var isValid = true
                switch holder.cwt.isValid() {
                case .success(.expired):
                    isValid = false
                default:
                    break
                }

                result.nationalRules = .success(.init(isValid: isValid,
                                                      validUntil: holder.expiresAt,
                                                      validFrom: holder.issuedAt,
                                                      dateError: nil,
                                                      isSwitzerlandOnly: true,
                                                      eolBannerIdentifier: nil))
                completionHandler(result)
                return
            }

            if certificate.immunisationType == nil {
                result.nationalRules = .failure(.NO_VALID_PRODUCT)
                completionHandler(result)
                return
            }

            let displayRulesResult = try? certLogic.checkDisplayRules(holder: holder).get()

            switch certLogic.checkRules(hcert: certificate) {
            case .success:
                result.nationalRules = .success(VerificationResult(isValid: true,
                                                                   validUntil: displayRulesResult?.validUntil,
                                                                   validFrom: displayRulesResult?.validFrom,
                                                                   dateError: nil,
                                                                   isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                   eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                completionHandler(result)
                return
            case let .failure(.TESTS_FAILED(tests)):
                switch tests.keys.first {
                case "GR-CH-0001":
                    result.nationalRules = .failure(.WRONG_DISEASE_TARGET)
                    completionHandler(result)
                case "VR-CH-0000":
                    result.nationalRules = .failure(.TOO_MANY_VACCINE_ENTRIES)
                    completionHandler(result)
                case "VR-CH-0001":
                    result.nationalRules = .failure(.NOT_FULLY_PROTECTED)
                    completionHandler(result)
                case "VR-CH-0002":
                    result.nationalRules = .failure(.NO_VALID_PRODUCT)
                    completionHandler(result)
                case "VR-CH-0003":
                    result.nationalRules = .failure(.NO_VALID_DATE)
                    completionHandler(result)
                case "VR-CH-0004":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .NOT_YET_VALID,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "VR-CH-0005":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .NOT_YET_VALID,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "VR-CH-0006":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "VR-CH-0007":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "VR-CH-0008":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "TR-CH-0000":
                    result.nationalRules = .failure(.TOO_MANY_TEST_ENTRIES)
                    completionHandler(result)
                case "TR-CH-0001":
                    result.nationalRules = .failure(.POSITIVE_RESULT)
                    completionHandler(result)
                case "TR-CH-0002":
                    result.nationalRules = .failure(.WRONG_TEST_TYPE)
                    completionHandler(result)
                case "TR-CH-0003":
                    result.nationalRules = .failure(.NO_VALID_PRODUCT)
                    completionHandler(result)
                case "TR-CH-0004":
                    result.nationalRules = .failure(.NO_VALID_DATE)
                    completionHandler(result)
                case "TR-CH-0005":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .NOT_YET_VALID,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "TR-CH-0006":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "TR-CH-0007":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "TR-CH-0008":
                    result.nationalRules = .failure(.NEGATIVE_RESULT)
                    completionHandler(result)
                case "TR-CH-0009":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "TR-CH-0010":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "TR-CH-0011":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .NOT_YET_VALID,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "TR-CH-0012":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "RR-CH-0000":
                    result.nationalRules = .failure(.TOO_MANY_RECOVERY_ENTRIES)
                    completionHandler(result)
                case "RR-CH-0001":
                    result.nationalRules = .failure(.NO_VALID_DATE)
                    completionHandler(result)
                case "RR-CH-0002":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .NOT_YET_VALID,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                case "RR-CH-0003":
                    result.nationalRules = .success(VerificationResult(isValid: false,
                                                                       validUntil: displayRulesResult?.validUntil,
                                                                       validFrom: displayRulesResult?.validFrom,
                                                                       dateError: .EXPIRED,
                                                                       isSwitzerlandOnly: displayRulesResult?.isSwitzerlandOnly,
                                                                       eolBannerIdentifier: displayRulesResult?.eolBannerIdentifier))
                    completionHandler(result)
                default:
                    result.nationalRules = .failure(.UNKNOWN_CERTLOGIC_FAILURE)
                    completionHandler(result)
                }
                return
            case .failure(.TEST_COULD_NOT_BE_PERFORMED(_)):
                result.nationalRules = .failure(.UNKNOWN_CERTLOGIC_FAILURE)
                return
            default:
                result.nationalRules = .failure(.NO_VALID_DATE)
                return
            }
        })
    }

    func getActiveModesForWallet() -> [CheckMode] {
        let list = trustListManager.trustStorage.nationalRules()
        return list.modeRules.walletActiveModes ?? list.modeRules.activeModes
    }

    func getActiveModesForVerifier() -> [CheckMode] {
        let list = trustListManager.trustStorage.nationalRules()
        return list.modeRules.verifierActiveModes
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
