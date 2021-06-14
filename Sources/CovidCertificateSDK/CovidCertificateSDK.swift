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

private var instance: ChCovidCert!

public enum CovidCertificateSDK {
    /// The current version of the SDK
    public static let frameworkVersion: String = "1.0.0"

    public static func initialize(environment: SDKEnvironment, apiKey: String) {
        precondition(instance == nil, "CovidCertificateSDK already initialized")
        instance = ChCovidCert(environment: environment, apiKey: apiKey, trustListManager: TrustlistManager())
    }

    public static func decode(encodedData: String) -> Result<DGCHolder, CovidCertError> {
        instancePrecondition()
        return instance.decode(encodedData: encodedData)
    }

    @available(OSX 10.13, *)
    public static func checkSignature(cose: DGCHolder, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        instancePrecondition()
        return instance.checkSignature(cose: cose, forceUpdate: forceUpdate, completionHandler)
    }

    public static func checkRevocationStatus(dgc: EuHealthCert, forceUpdate: Bool, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        instancePrecondition()
        return instance.checkRevocationStatus(dgc: dgc, forceUpdate: forceUpdate, completionHandler)
    }

    public static func checkNationalRules(dgc: EuHealthCert, forceUpdate: Bool, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        instancePrecondition()
        return instance.checkNationalRules(dgc: dgc, forceUpdate: forceUpdate, completionHandler)
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

    public static var apiKey : String {
        instancePrecondition()
        return instance.apiKey
    }
}
