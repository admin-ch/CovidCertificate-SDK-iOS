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

class TrustStorage : Codable {
    // MARK: - Storage

    public static let shared = TrustStorage()

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

    // MARK: - Revocation List

    public func revokedCertificates() -> [String] {
        return Self.sharedStorage.revocationList.revokedCerts
    }

    public func updateRevocationList(_ list: RevocationList) -> Bool {
        Self.sharedStorage.revocationList = list
        return Self.secureStorage.saveSynchronously(Self.sharedStorage)
    }

    // MARK: - Certificate List

    public func updateCertificateList(_ update: TrustCertificates) -> Bool {
        // add all certificates from update
        let newCerts = update.certs.filter { c in Self.sharedStorage.activeCertificates.contains { $0.keyId == c.keyId } }
        Self.sharedStorage.activeCertificates.append(contentsOf: newCerts)
        return Self.secureStorage.saveSynchronously(Self.sharedStorage)
    }

    public func updateActiveCertificates(_ activeCertificates : ActiveTrustCertificates) -> Bool {
        // remove all certificates that are not active
        Self.sharedStorage.activeCertificates.removeAll { c in
            activeCertificates.activeKeyIds.contains(c.keyId)
        }

        return Self.secureStorage.saveSynchronously(Self.sharedStorage)
    }
}

class Storage : Codable {
    public var revocationList = RevocationList()
    public var activeCertificates : [TrustCertificate] = []
}
