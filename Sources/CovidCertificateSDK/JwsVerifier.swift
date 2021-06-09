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
}

/// A JWT token verifier
public class JWSVerifier {
    private let rootCA: SecCertificate

    /// Initializes a verifier with a public key
    ///
    /// - Parameters:
    ///   - publicKey: The public key to verify the JWT signiture
    public init?(rootData: Data) {
        guard let rootFromData = SecCertificateCreateWithData(nil, rootData as CFData) else{
            return nil
        }
        rootCA = rootFromData
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
            var chain : [SecCertificate] = []
            guard let certificates = unsafeJWT.header.x5c else {
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
            let secTrust = optionalTrust!    // Safe to force unwrap now

            // Since we only want to trust OUR root CA we overwrite all default trust certificates with our rootCA
            let anchorStatus = SecTrustSetAnchorCertificates(secTrust, [rootCA] as CFArray)
            guard anchorStatus == errSecSuccess else {
                completionHandler(.failure(JWSError.CERTIFICATE_CHAIN_ERROR))
                return
            }
            
            // Since we use each time a new trust object, this call should be safe
            if #available(iOS 13.0, *) {
                DispatchQueue.global().async {
                    SecTrustEvaluateAsyncWithError(secTrust, DispatchQueue.global()) { trust, result, error in
                        if result {
                            self.verifySignature(jwtString: jwtString, leafCertificateData: certificates[0].data(using: .utf8), completionHandler)
                        } else {
                            completionHandler(.failure(.SIGNATURE_INVALID))
                            return
                        }
                    }
                }
            } else {
                SecTrustEvaluateAsync(secTrust, DispatchQueue.global()) {trust, result in
                    if result == .proceed {
                    self.verifySignature(jwtString: jwtString, leafCertificateData: certificates[0].data(using: .utf8), completionHandler)
                    } else {
                        completionHandler(.failure(.SIGNATURE_INVALID))
                        return
                    }
                }
            }
        
        }
        catch JWTError.invalidJWTString {
            completionHandler(.failure(JWSError.SIGNATURE_INVALID))
            return
        }
        catch JWTError.failedVerification{
            completionHandler(.failure(JWSError.PARSING_ERROR))
            return
        }
        catch {
            completionHandler(.failure(JWSError.DECODING_ERROR))
            return
        }
        
    }
    
    private func verifySignature<ClaimType: JWTExtension>(jwtString: String, leafCertificateData: Data?, _ completionHandler: @escaping (_ claims: Result<ClaimType,JWSError> ) -> Void) {
        guard let leafCertificate = leafCertificateData else {
            completionHandler(.failure(JWSError.CERTIFICATE_CHAIN_ERROR))
            return
        }
        let jwtVerifier = JWTVerifier.rs256(certificate: leafCertificate)
        do {
            let jwt = try JWT<ClaimType>(jwtString: jwtString, verifier: jwtVerifier)
            
            let validationResult = jwt.validateClaims(leeway: 10)
            guard validationResult == .success else {
                completionHandler(.failure(JWSError.JWT_CLAIM_VALIDATION_FAILED))
                return
            }
            completionHandler(.success(jwt.claims))
            return
        }
        catch JWTError.invalidJWTString {
            completionHandler(.failure(JWSError.SIGNATURE_INVALID))
            return
        }
        catch JWTError.failedVerification{
            completionHandler(.failure(JWSError.PARSING_ERROR))
            return
        }
        catch {
            completionHandler(.failure(JWSError.DECODING_ERROR))
            return
        }
    }
}

private struct InsecureJwt: Claims {}
