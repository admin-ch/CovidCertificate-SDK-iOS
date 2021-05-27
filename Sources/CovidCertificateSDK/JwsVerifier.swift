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
    case PARSING_ERROR
    case DECODING_ERROR
}

/// A JWT token verifier
public class CovidCertJWSVerifier {
    private let jwtVerifier: JWTVerifier

    /// Initializes a verifier with a public key
    ///
    /// - Parameters:
    ///   - publicKey: The public key to verify the JWT signiture
    public init(publicKey: Data) {
        jwtVerifier = JWTVerifier.rs256(publicKey: publicKey)
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
            let jwt = try JWT<ClaimType>(jwtString: jwtString, verifier: jwtVerifier)
            
            let validationResult = jwt.validateClaims(leeway: 10)
            guard validationResult == .success else {
                throw CovidCertJWSError.SIGNATURE_INVALID
            }

            return jwt.claims

        } catch {
            throw CovidCertJWSError.PARSING_ERROR
        }
    }
}

