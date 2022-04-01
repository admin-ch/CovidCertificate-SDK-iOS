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

    public static var isInitialized: Bool {
        instance != nil
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

        public static func check(holder: VerifierCertificateHolder, forceUpdate: Bool, mode: CheckMode?, _ completionHandler: @escaping (CheckResults) -> Void) {
            instancePrecondition()
            instance.check(countryCode: CountryCodes.Switzerland, arrivalDate: Date(), holder: holder.value, forceUpdate: forceUpdate, modes: mode != nil ? [mode!] : []) { result in
                completionHandler(result.anonymized)
            }
        }

        public static var activeModes: [CheckMode] {
            instancePrecondition()
            return instance.getActiveModesForVerifier()
        }
    }

    public enum Wallet {
        public static func decode(encodedData: String) -> Result<CertificateHolder, CovidCertError> {
            instancePrecondition()
            return instance.decode(encodedData: encodedData)
        }

        public static func check(holder: CertificateHolder, forceUpdate: Bool, modes: [CheckMode], _ completionHandler: @escaping (CheckResults) -> Void) {
            instancePrecondition()
            return instance.check(countryCode: CountryCodes.Switzerland, arrivalDate: Date(), holder: holder, forceUpdate: forceUpdate, modes: modes, completionHandler)
        }
        
        public static func check(countryCode: String, arrivalDate: Date, holder: CertificateHolder, forceUpdate: Bool, modes: [CheckMode], _ completionHandler: @escaping (CheckResults) -> Void) {
            instancePrecondition()
            return instance.check(countryCode: countryCode, arrivalDate: arrivalDate, holder: holder, forceUpdate: forceUpdate, modes: modes, completionHandler)
        }
        
        
        public static func foreignRulesCountryCodes(forceUpdate: Bool = false, _ completionHandler: @escaping (Result<[String], NetworkError>) -> Void) {
            instancePrecondition()
            return instance.getForeignRulesCountryCodes(forceUpdate: forceUpdate, completionHandler)
        }

        public static var activeModes: [CheckMode] {
            instancePrecondition()
            return instance.getActiveModesForWallet()
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
        instancePrecondition()
        URLSession.evaluator.useCertificatePinning = options.certificatePinning
        TrustListUpdate.allowedServerTimeDiff = options.allowedServerTimeDiff
        TrustListUpdate.timeshiftDetectionEnabled = options.timeshiftDetectionEnabled
        instance.options = options
    }
}
