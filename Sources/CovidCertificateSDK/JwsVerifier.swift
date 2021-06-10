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
import SwiftJWT

/// Reexport the Claims type for custom JWS'. Claims includes Codable and since all JWT properties are optional, any Codable type can be used here.
public typealias JWTExtension = Claims

public enum JWSError: Error, Equatable {
    case SIGNATURE_INVALID
    case JWT_CLAIM_VALIDATION_FAILED
    case PARSING_ERROR
    case DECODING_ERROR
    case CERTIFICATE_CHAIN_ERROR
    case COMMON_NAME_MISMATCH
}

/// A JWT token verifier
public class JWSVerifier {
    private let rootCA: SecCertificate
    private let leafCommonName: String?

    /// Initializes a verifier with a public key
    ///
    /// - Parameters:
    ///   - publicKey: The public key to verify the JWT signiture
    ///   - leafCN: Verify common name which must match in leaf certificate
    public init?(rootData: Data, leafCertMustMatch leafCN: String? = nil) {
        guard let rootFromData = SecCertificateCreateWithData(nil, rootData as CFData) else {
            return nil
        }
        rootCA = rootFromData
        leafCommonName = leafCN
    }

    /// Verify and return the claims from the JWT token
    ///
    /// Validate the time based standard JWT claims (if included).
    /// This function checks that the "exp" (expiration time) is in the future
    /// and the "iat" (issued at) and "nbf" (not before) headers are in the past,
    ///
    /// - Parameters:
    ///   - httpBody: The HTTP body returned
    ///   - claimsLeeway: The time in seconds that the JWT can be invalid but still accepted to account for clock differences.
    /// - Throws: `CovidCertJWSError` in case of validation failures
    /// - Returns: The verified claims
    public func verifyAndDecode<ClaimType: JWTExtension>(httpBody: Data, claimsLeeway _: TimeInterval = 10, _ completionHandler: @escaping (Result<ClaimType, JWSError>) -> Void) {
        guard let jwtString = String(data: httpBody, encoding: .utf8) else {
            completionHandler(.failure(JWSError.DECODING_ERROR))
            return
        }
        do {
            let unsafeJWT = try JWT<InsecureJwt>(jwtString: jwtString)
            var chain: [SecCertificate] = []
            guard let certificates = unsafeJWT.header.x5c else {
                completionHandler(.failure(JWSError.CERTIFICATE_CHAIN_ERROR))
                return
            }

            guard let leafCertificateData = certificates[0].data(using: .utf8) else {
                completionHandler(.failure(JWSError.CERTIFICATE_CHAIN_ERROR))
                return
            }

            for cert in certificates {
                guard let certData = Data(base64Encoded: cert),
                      let certKey = SecCertificateCreateWithData(nil, certData as CFData)
                else {
                    completionHandler(.failure(JWSError.CERTIFICATE_CHAIN_ERROR))
                    return
                }
                chain.append(certKey)
            }

            var optionalTrust: SecTrust?

            let status = SecTrustCreateWithCertificates(chain as AnyObject,
                                                        SecPolicyCreateBasicX509(),
                                                        &optionalTrust)
            guard status == errSecSuccess else {
                completionHandler(.failure(JWSError.CERTIFICATE_CHAIN_ERROR))
                return
            }
            let secTrust = optionalTrust! // Safe to force unwrap now

            // Since we only want to trust OUR root CA we overwrite all default trust certificates with our rootCA
            let anchorStatus = SecTrustSetAnchorCertificates(secTrust, [rootCA] as CFArray)
            guard anchorStatus == errSecSuccess else {
                completionHandler(.failure(JWSError.CERTIFICATE_CHAIN_ERROR))
                return
            }

            if #available(iOS 13.0, macOS 10.15, *) {
                DispatchQueue.global().async {
                    SecTrustEvaluateAsyncWithError(secTrust, DispatchQueue.global()) { _, result, _ in
                        if !result {
                            completionHandler(.failure(.SIGNATURE_INVALID))
                            return
                        }

                        self.continueWithCommonNameEvaluation(jwtString: jwtString, leafCertificate: chain[0], leafCertificateData: leafCertificateData, completionHandler)
                    }
                }
            } else {
                SecTrustEvaluateAsync(secTrust, DispatchQueue.global()) { _, result in
                    if result != .proceed {
                        completionHandler(.failure(.SIGNATURE_INVALID))
                        return
                    }

                    self.continueWithCommonNameEvaluation(jwtString: jwtString, leafCertificate: chain[0], leafCertificateData: leafCertificateData, completionHandler)
                }
            }
        } catch JWTError.invalidJWTString {
            completionHandler(.failure(JWSError.SIGNATURE_INVALID))
        } catch JWTError.failedVerification {
            completionHandler(.failure(JWSError.PARSING_ERROR))
        } catch {
            completionHandler(.failure(JWSError.DECODING_ERROR))
            return
        }
    }

    private func continueWithCommonNameEvaluation<ClaimType: JWTExtension>(jwtString: String, leafCertificate: SecCertificate, leafCertificateData: Data, _ completionHandler: @escaping (Result<ClaimType, JWSError>) -> Void) {
        if leafCommonName != nil,
           !isLeafCertificateValid(leafCertificate: leafCertificate) {
            completionHandler(.failure(.COMMON_NAME_MISMATCH))
            return
        }

        // Continue with signature verification
        verifySignature(jwtString: jwtString, leafCertificateData: leafCertificateData, completionHandler)
    }

    private func isLeafCertificateValid(leafCertificate: SecCertificate) -> Bool {
        var commonName: CFString?
        let result = SecCertificateCopyCommonName(leafCertificate, &commonName)
        if result != errSecSuccess {
            return false
        }
        guard let cfName = commonName
        else {
            return false
        }
        return (cfName as String) == leafCommonName
    }

    private func verifySignature<ClaimType: JWTExtension>(jwtString: String, leafCertificateData: Data, _ completionHandler: @escaping (_ claims: Result<ClaimType, JWSError>) -> Void) {
        let jwtVerifier = JWTVerifier.rs256(certificate: leafCertificateData)
        do {
            let jwt = try JWT<ClaimType>(jwtString: jwtString, verifier: jwtVerifier)

            let validationResult = jwt.validateClaims(leeway: 10)
            guard validationResult == .success else {
                completionHandler(.failure(JWSError.JWT_CLAIM_VALIDATION_FAILED))
                return
            }
            completionHandler(.success(jwt.claims))
            return
        } catch JWTError.invalidJWTString {
            completionHandler(.failure(JWSError.SIGNATURE_INVALID))
        } catch JWTError.failedVerification {
            completionHandler(.failure(JWSError.PARSING_ERROR))
        } catch {
            completionHandler(.failure(JWSError.DECODING_ERROR))
            return
        }
    }
}

private struct InsecureJwt: Claims {}
