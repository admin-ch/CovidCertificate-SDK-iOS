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

    public static func initialize(environment: SDKEnvironment) {
        precondition(instance == nil, "CovidCertificateSDK already initialized")
        instance = ChCovidCert(environment: environment, trustList: StaticTrustlist())
    }

    public static func decode(encodedData: String) -> Result<DGCHolder, CovidCertError> {
        instancePrecondition()
        return instance.decode(encodedData: encodedData)
    }

    @available(OSX 10.13, *)
    public static func checkSignature(cose: DGCHolder, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        instancePrecondition()
        return instance.checkSignature(cose: cose, completionHandler)
    }

    public static func checkRevocationStatus(dgc: EuHealthCert, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void) {
        instancePrecondition()
        return instance.checkRevocationStatus(dgc: dgc, completionHandler)
    }

    public static func checkNationalRules(dgc: EuHealthCert, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        instancePrecondition()
        return instance.checkNationalRules(dgc: dgc, completionHandler)
    }

    private static func instancePrecondition() {
        precondition(instance != nil, "CovidCertificateSDK not initialized, call `initialize()`")
    }

    public static var currentEnvironment: SDKEnvironment {
        instancePrecondition()
        return instance.environment
    }
}
