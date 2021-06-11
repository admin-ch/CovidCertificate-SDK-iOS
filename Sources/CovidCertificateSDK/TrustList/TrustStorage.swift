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
    func certificateSince() -> String
    func updateCertificateList(_ update: TrustCertificates, since: String) -> Bool
    func updateActiveCertificates(_ activeCertificates: ActiveTrustCertificates) -> Bool
    func certificateListIsValid() -> Bool

    func nationalRulesListIsStillValid() -> Bool
    func updateNationalRules(_ update: NationalRulesList) -> Bool
    func nationalRules() -> NationalRulesList
}

class TrustStorage: TrustStorageProtocol {
    // MARK: - Storage

    private static var sharedStorage = Storage()
    private static let secureStorage = SecureStorage<Storage>()

    let revocationQueue = DispatchQueue(label: "storage.sync.revocation")
    let certificateQueue = DispatchQueue(label: "storage.sync.certificate")
    let nationalQueue = DispatchQueue(label: "storage.sync.national")

    // MARK: - API

    public func initialize() {
        Self.secureStorage.load { storage in
            if let s = storage {
                Self.sharedStorage = s
            }
        }
    }

    init() {
        initialize()
    }

    // MARK: - Revocation List

    public func revokedCertificates() -> [String] {
        return revocationQueue.sync {
            return Self.sharedStorage.revocationList.revokedCerts
        }
    }

    public func updateRevocationList(_ list: RevocationList) -> Bool {
        revocationQueue.sync {
            Self.sharedStorage.revocationList = list
            Self.sharedStorage.lastRevocationListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)

            return Self.secureStorage.saveSynchronously(Self.sharedStorage)
        }
    }

    func revocationListIsValid() -> Bool {
        return revocationQueue.sync {
            return isStillValid(lastDownloadTimeStamp: Self.sharedStorage.lastRevocationListDownload, validDuration: Self.sharedStorage.revocationList.validDuration)
        }
    }

    // MARK: - Certificate List

    func updateCertificateList(_ update: TrustCertificates, since: String) -> Bool {
        // add all certificates from update
        return certificateQueue.sync {
            Self.sharedStorage.certificateSince = since
            Self.sharedStorage.activeCertificates.append(contentsOf: update.certs)
            return Self.secureStorage.saveSynchronously(Self.sharedStorage)
        }
    }

    func updateActiveCertificates(_ activeCertificates: ActiveTrustCertificates) -> Bool {
        // remove all certificates that are not active
        return certificateQueue.sync {
            Self.sharedStorage.activeCertificates.removeAll { c in
                activeCertificates.activeKeyIds.contains(c.keyId)
            }

            Self.sharedStorage.lastCertificateListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)

            return Self.secureStorage.saveSynchronously(Self.sharedStorage)
        }
    }

    func activeCertificatePublicKeys() -> [TrustListPublicKey] {
        return certificateQueue.sync {
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
    }

    func certificateSince() -> String {
        return certificateQueue.sync {
            return Self.sharedStorage.certificateSince
        }
    }

    func certificateListIsValid() -> Bool {
        return certificateQueue.sync {
            return isStillValid(lastDownloadTimeStamp: Self.sharedStorage.lastCertificateListDownload, validDuration: Self.sharedStorage.certificateValidDuration)
        }
    }

    // MARK: - National rules

    func nationalRulesListIsStillValid() -> Bool {
        return nationalQueue.sync {
            return isStillValid(lastDownloadTimeStamp: Self.sharedStorage.lastNationalRulesListDownload, validDuration: Self.sharedStorage.nationalRulesList.validDuration)
        }
    }

    func updateNationalRules(_ update: NationalRulesList) -> Bool {
        return nationalQueue.sync {
            Self.sharedStorage.nationalRulesList = update
            Self.sharedStorage.lastNationalRulesListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            return Self.secureStorage.saveSynchronously(Self.sharedStorage)
        }
    }

    func nationalRules() -> NationalRulesList {
        return nationalQueue.sync {
            return Self.sharedStorage.nationalRulesList
        }
    }

    // MARK: - Validity

    private func isStillValid(lastDownloadTimeStamp: Int64, validDuration: Int64) -> Bool {
        let stillValidUntil = lastDownloadTimeStamp + validDuration
        let validUntilDate = Date(timeIntervalSince1970: Double(stillValidUntil) / 1000.0)
        return Date().isBefore(validUntilDate)
    }
}

class Storage: Codable {
    public var revocationList = RevocationList()
    public var lastRevocationListDownload: Int64 = 0

    public var activeCertificates: [TrustCertificate] = []
    public var certificateSince: String = ""
    public var certificateValidDuration: Int64 = 0
    public var lastCertificateListDownload: Int64 = 0

    public var nationalRulesList = NationalRulesList()
    public var lastNationalRulesListDownload: Int64 = 0
}
