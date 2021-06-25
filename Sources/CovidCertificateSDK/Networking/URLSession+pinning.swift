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
import Security

extension URLSession {
    static let evaluator = CertificateEvaluator()

    static let certificatePinned: URLSession = {
        let session = URLSession(configuration: .default,
                                 delegate: URLSession.evaluator,
                                 delegateQueue: nil)
        return session
    }()
}

class CertificateEvaluator: NSObject, URLSessionDelegate {
    typealias AuthenticationChallengeCompletion = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

    private var trustManager: UBServerTrustManager

    private(set) static var useCertificatePinning: Bool = true

    var useCertificatePinning: Bool {
        get {
            Self.useCertificatePinning
        }
        set {
            Self.useCertificatePinning = newValue
            if newValue {
                trustManager = Self.getServerTrustManager()
            } else {
                trustManager = Self.getEmptyServerTrustManager()
            }
        }
    }

    override init() {
        if Self.useCertificatePinning {
            trustManager = Self.getServerTrustManager()
        } else {
            trustManager = Self.getEmptyServerTrustManager()
        }
    }

    private static func getEmptyServerTrustManager() -> UBServerTrustManager {
        UBServerTrustManager(evaluators: [:], default: UBDisabledEvaluator())
    }

    private static func getServerTrustManager() -> UBServerTrustManager {
        var evaluators: [String: UBServerTrustEvaluator] = [:]

        let bundle = Bundle.module

        guard let certificate = bundle.getCertificate(with: "Amazon_Root_CA1") else {
            fatalError("Could not load certificate for pinned host")
        }
        let evaluator = UBPinnedCertificatesTrustEvaluator(certificates: [certificate])

        // all these hosts have a seperate certificate
        let hosts = ["www.cc-d.bit.admin.ch",
                     "www.cc-a.bit.admin.ch",
                     "www.cc.bit.admin.ch"]
        for host in hosts {
            evaluators[host] = evaluator
        }

        return UBServerTrustManager(evaluators: evaluators)
    }

    // MARK: - URLSessionDelegate

    private typealias ChallengeEvaluation = (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?, error: Error?)
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let evaluation: ChallengeEvaluation

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            evaluation = attemptServerTrustAuthentication(with: challenge)
        default:
            evaluation = (.cancelAuthenticationChallenge, nil, nil)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }

    /// :nodoc:
    private func attemptServerTrustAuthentication(with challenge: URLAuthenticationChallenge) -> ChallengeEvaluation {
        let host = challenge.protectionSpace.host

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            return (.cancelAuthenticationChallenge, nil, nil)
        }

        do {
            guard let evaluator = trustManager.serverTrustEvaluator(forHost: host) else {
                // If we don't have a evaluator we fail
                return (.cancelAuthenticationChallenge, nil, nil)
            }

            try evaluator.evaluate(trust, forHost: host)

            return (.useCredential, URLCredential(trust: trust), nil)
        } catch {
            return (.cancelAuthenticationChallenge, nil, error)
        }
    }
}

extension Bundle {
    func getCertificate(with name: String, fileExtension: String = "der") -> SecCertificate? {
        if let certificateURL = url(forResource: name, withExtension: fileExtension),
           let certificateData = try? Data(contentsOf: certificateURL),
           let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) {
            return certificate
        }
        return nil
    }
}
