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

    func activeCertificatePublicKeys() -> [TrustListPublicKey]
    func certificateSince() -> Int64
    func updateCertificateList(_ update: TrustCertificates, since: Int64) -> Bool
    func updateActiveCertificates(_ activeCertificates : ActiveTrustCertificates) -> Bool
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
        return Self.secureStorage.saveSynchronously(Self.sharedStorage)
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
}

class Storage : Codable {
    public var revocationList = RevocationList()

    public var activeCertificates : [TrustCertificate] = []
    public var certificateSince : Int64 = 0
}
