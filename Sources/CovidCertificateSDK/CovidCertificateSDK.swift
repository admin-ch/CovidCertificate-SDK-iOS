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

private var instance: CovidCertificateImpl!

public enum CovidCertificateSDK {
    /// The current version of the SDK
    public static let frameworkVersion: String = "1.0.0"

    public static func initialize(environment: SDKEnvironment, apiKey: String) {
        precondition(instance == nil, "CovidCertificateSDK already initialized")
        instance = CovidCertificateImpl(environment: environment, apiKey: apiKey, trustListManager: TrustlistManager())
        instance.updateMetadata()
    }

    public enum Verifier {
        public static func decode(encodedData: String) -> Result<VerifierCertificateHolder, CovidCertError> {
            instancePrecondition()
            switch instance.decode(encodedData: encodedData) {
            case let .success(holder):
                return .success(VerifierCertificateHolder(holder: holder))
            case let .failure(error):
                return .failure(error)
            }
        }

        public static func check(holder: VerifierCertificateHolder, forceUpdate: Bool, _ completionHandler: @escaping (CheckResults) -> Void) {
            instancePrecondition()
            instance.check(holder: holder.value, forceUpdate: forceUpdate) { result in
                switch result.nationalRules {
                // don't expose the validity range for verification apps
                case let .success(nationalRulesResult):
                    return completionHandler(CheckResults(signature: result.signature,
                                                          revocationStatus: result.revocationStatus,
                                                          nationalRules: .success(.init(isValid: nationalRulesResult.isValid,
                                                                                        validUntil: nil,
                                                                                        validFrom: nil,
                                                                                        dateError: nil,
                                                                                        isSwitzerlandOnly: nil))))
                // expose networking errors for verification apps
                case .failure(.NETWORK_NO_INTERNET_CONNECTION),
                     .failure(.NETWORK_PARSE_ERROR),
                     .failure(.NETWORK_ERROR),
                     .failure(.TIME_INCONSISTENCY(timeShift: _)):
                    return completionHandler(result)
                case .failure:
                    // Strip specific national rules error for verification apps
                    return completionHandler(.init(signature: result.signature,
                                                   revocationStatus: result.revocationStatus,
                                                   nationalRules: .failure(.UNKNOWN_TEST_FAILURE)))
                }
            }
        }
    }

    public enum Wallet {
        public static func decode(encodedData: String) -> Result<CertificateHolder, CovidCertError> {
            instancePrecondition()
            return instance.decode(encodedData: encodedData)
        }

        public static func check(holder: CertificateHolder, forceUpdate: Bool, _ completionHandler: @escaping (CheckResults) -> Void) {
            instancePrecondition()
            return instance.check(holder: holder, forceUpdate: forceUpdate, completionHandler)
        }
    }

    public static func restartTrustListUpdate(completionHandler: @escaping () -> Void, updateTimeInterval: TimeInterval) {
        instancePrecondition()
        instance.restartTrustListUpdate(completionHandler: completionHandler, updateTimeInterval: updateTimeInterval)
    }

    private static func instancePrecondition() {
        precondition(instance != nil, "CovidCertificateSDK not initialized, call `initialize()`")
    }

    public static var currentEnvironment: SDKEnvironment {
        instancePrecondition()
        return instance.environment
    }

    public static var apiKey: String {
        instancePrecondition()
        return instance.apiKey
    }

    public static func setOptions(options: SDKOptions) {
        URLSession.evaluator.useCertificatePinning = options.certificatePinning
        TrustListUpdate.allowedServerTimeDiff = options.allowedServerTimeDiff
        TrustListUpdate.timeshiftDetectionEnabled = options.timeshiftDetectionEnabled
    }
}
