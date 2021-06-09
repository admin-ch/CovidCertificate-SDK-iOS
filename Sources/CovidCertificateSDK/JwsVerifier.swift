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

public enum CovidCertJWSError: Error, Equatable {
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
    @discardableResult
    public func verifyAndDecode<ClaimType: JWTExtension>(claimType: ClaimType.Type, httpBody: Data, claimsLeeway _: TimeInterval = 10) throws -> ClaimType {
        guard let jwtString = String(data: httpBody, encoding: .utf8) else {
            throw CovidCertJWSError.DECODING_ERROR
        }
        do {
            let unsafeJWT = try JWT<InsecureJwt>(jwtString: jwtString)
            var chain : [SecCertificate] = []
            guard let certificates = unsafeJWT.header.x5c else {
                throw CovidCertJWSError.CERTIFICATE_CHAIN_ERROR
            }
            
            for cert in certificates {
                guard let certData = Data(base64Encoded: cert),
                      let certKey = SecCertificateCreateWithData(nil, certData as CFData)
                else {
                    throw CovidCertJWSError.CERTIFICATE_CHAIN_ERROR
                }
                chain.append(certKey)
            }
            
            let completeChain = chain + [rootCA]
            
            var optionalTrust: SecTrust?
            let status = SecTrustCreateWithCertificates(completeChain as AnyObject,
                                                        SecPolicyCreateBasicX509(),
                                                        &optionalTrust)
            guard status == errSecSuccess else { throw CovidCertJWSError.CERTIFICATE_CHAIN_ERROR }
            let secTrust = optionalTrust!    // Safe to force unwrap now

            // Since we only want to trust OUR root CA we overwrite all default trust certificates with our rootCA
            let anchorStatus = SecTrustSetAnchorCertificates(secTrust, [rootCA] as CFArray)
            guard anchorStatus == errSecSuccess else {
                throw CovidCertJWSError.CERTIFICATE_CHAIN_ERROR
            }
            
            // Since we use each time a new trust object, this call should be safe
            let result = SecTrustEvaluateWithError(secTrust, nil)
            if result == false {
                throw CovidCertJWSError.CERTIFICATE_CHAIN_ERROR
            }
            
            // from here we trust the public key
            
            guard let leafCertificate = certificates[0].data(using: .utf8) else {
                throw CovidCertJWSError.CERTIFICATE_CHAIN_ERROR
            }
            let jwtVerifier = JWTVerifier.rs256(certificate: leafCertificate)
            
            let jwt = try JWT<ClaimType>(jwtString: jwtString, verifier: jwtVerifier)
            
            let validationResult = jwt.validateClaims(leeway: 10)
            guard validationResult == .success else {
                throw CovidCertJWSError.JWT_CLAIM_VALIDATION_FAILED
            }

            return jwt.claims

        }
        catch JWTError.invalidJWTString {
            throw CovidCertJWSError.SIGNATURE_INVALID
        }
        catch JWTError.failedVerification{
            throw CovidCertJWSError.PARSING_ERROR
        }
    }
}

private struct InsecureJwt: Claims {}
