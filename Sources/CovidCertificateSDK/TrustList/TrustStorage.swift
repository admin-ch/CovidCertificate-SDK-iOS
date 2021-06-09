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

public protocol TrustStorageProtocol {
    func revokedCertificates() -> [String]
    func updateRevocationList(_ list: RevocationList) -> Bool
    func revocationListIsValid() -> Bool

    func activeCertificatePublicKeys() -> [TrustListPublicKey]
    func certificateSince() -> Int64
    func updateCertificateList(_ update: TrustCertificates, since: Int64) -> Bool
    func updateActiveCertificates(_ activeCertificates : ActiveTrustCertificates) -> Bool
    func certificateListIsValid() -> Bool
}

class TrustStorage : TrustStorageProtocol, Codable {

    // MARK: - Storage
    private static var sharedStorage = Storage()
    private static let secureStorage = SecureStorage<Storage>()

    // MARK: - API

    public func initialize() {
        Self.secureStorage.load { storage in
            if let s = storage {
                Self.sharedStorage = s
            }
        }
    }

    init() {
        self.initialize()
    }

    // MARK: - Revocation List

    public func revokedCertificates() -> [String] {
        return Self.sharedStorage.revocationList.revokedCerts
    }

    public func updateRevocationList(_ list: RevocationList) -> Bool {
        Self.sharedStorage.revocationList = list
        Self.sharedStorage.lastRevocationListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)

        return Self.secureStorage.saveSynchronously(Self.sharedStorage)
    }

    func revocationListIsValid() -> Bool {
        let stillValidUntil = Self.sharedStorage.lastRevocationListDownload + Self.sharedStorage.revocationList.validDuration
        let validUntilDate = Date(timeIntervalSince1970: Double(stillValidUntil) / 1000.0)

        return Date().isBefore(validUntilDate)
    }

    // MARK: - Certificate List

    func updateCertificateList(_ update: TrustCertificates, since: Int64) -> Bool {
        // add all certificates from update
        Self.sharedStorage.certificateSince = since
        Self.sharedStorage.activeCertificates.append(contentsOf: update.certs)
        return Self.secureStorage.saveSynchronously(Self.sharedStorage)
    }

    func updateActiveCertificates(_ activeCertificates : ActiveTrustCertificates) -> Bool {
        // remove all certificates that are not active
        Self.sharedStorage.activeCertificates.removeAll { c in
            activeCertificates.activeKeyIds.contains(c.keyId)
        }

        Self.sharedStorage.lastCertificateListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)

        return Self.secureStorage.saveSynchronously(Self.sharedStorage)
    }

    func activeCertificatePublicKeys() -> [TrustListPublicKey] {
        return Self.sharedStorage.activeCertificates.compactMap { t in
            if t.alg == "RS256" {
                return TrustListPublicKey(keyId: t.keyId, withRsaKey: t.subjectPublicKeyInfo)
            } else if t.alg == "ES256" {
                return TrustListPublicKey(keyId: t.keyId, withX: t.x, andY: t.y)
            } else {
                return nil
            }
        }
    }

    func certificateSince() -> Int64 {
        return Self.sharedStorage.certificateSince
    }

    func certificateListIsValid() -> Bool {
        let stillValidUntil = Self.sharedStorage.lastCertificateListDownload + Self.sharedStorage.certificateValidDuration
        let validUntilDate = Date(timeIntervalSince1970: Double(stillValidUntil) / 1000.0)

        return Date().isBefore(validUntilDate)
    }
}

class Storage : Codable {
    public var revocationList = RevocationList()
    public var lastRevocationListDownload : Int64 = 0

    public var activeCertificates : [TrustCertificate] = []
    public var certificateSince : Int64 = 0
    public var certificateValidDuration : Int64 = 0
    public var lastCertificateListDownload : Int64 = 0
}
