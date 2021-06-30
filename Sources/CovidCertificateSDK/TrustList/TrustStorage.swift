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

protocol TrustStorageProtocol {
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

    private lazy var nationalRulesStorage = self.nationalRulesSecureStorage.loadSynchronously() ?? NationalRulesStorage()
    private let nationalRulesSecureStorage = SecureStorage<NationalRulesStorage>(name: "national_rules")

    private lazy var activeCertificatesStorage = self.activeCertificatesSecureStorage.loadSynchronously() ?? ActiveCertificatesStorage()
    private let activeCertificatesSecureStorage = SecureStorage<ActiveCertificatesStorage>(name: "active_certificates")

    private lazy var revocationStorage = self.revocationSecureStorage.loadSynchronously() ?? RevocationStorage()
    private let revocationSecureStorage = SecureStorage<RevocationStorage>(name: "revocation")

    let revocationQueue = DispatchQueue(label: "storage.sync.revocation")
    let certificateQueue = DispatchQueue(label: "storage.sync.certificate")
    let nationalQueue = DispatchQueue(label: "storage.sync.national")

    // MARK: - Revocation List

    func revokedCertificates() -> [String] {
        return revocationQueue.sync {
            return self.revocationStorage.revocationList.revokedCerts
        }
    }

    func updateRevocationList(_ list: RevocationList) -> Bool {
        revocationQueue.sync {
            self.revocationStorage.revocationList = list
            self.revocationStorage.lastRevocationListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            return self.revocationSecureStorage.saveSynchronously(self.revocationStorage)
        }
    }

    func revocationListIsValid() -> Bool {
        return revocationQueue.sync {
            return isStillValid(lastDownloadTimeStamp: self.revocationStorage.lastRevocationListDownload, validDuration: self.revocationStorage.revocationList.validDuration)
        }
    }

    // MARK: - Certificate List

    func updateCertificateList(_ update: TrustCertificates, since: String) -> Bool {
        // add all certificates from update
        return certificateQueue.sync {
            self.activeCertificatesStorage.certificateSince = since
            self.activeCertificatesStorage.activeCertificates.append(contentsOf: update.certs)
            return self.activeCertificatesSecureStorage.saveSynchronously(self.activeCertificatesStorage)
        }
    }

    func updateActiveCertificates(_ activeCertificates: ActiveTrustCertificates) -> Bool {
        // remove all certificates that are not active
        return certificateQueue.sync {
            self.activeCertificatesStorage.activeCertificates.removeAll { c in
                !activeCertificates.activeKeyIds.contains(c.keyId)
            }

            self.activeCertificatesStorage.lastCertificateListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            self.activeCertificatesStorage.certificateValidDuration = activeCertificates.validDuration

            return self.activeCertificatesSecureStorage.saveSynchronously(self.activeCertificatesStorage)
        }
    }

    func activeCertificatePublicKeys() -> [TrustListPublicKey] {
        return certificateQueue.sync {
            return self.activeCertificatesStorage.activeCertificates.compactMap { t in
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
            return self.activeCertificatesStorage.certificateSince
        }
    }

    func certificateListIsValid() -> Bool {
        return certificateQueue.sync {
            return isStillValid(lastDownloadTimeStamp: self.activeCertificatesStorage.lastCertificateListDownload, validDuration: self.activeCertificatesStorage.certificateValidDuration)
        }
    }

    // MARK: - National rules

    func nationalRulesListIsStillValid() -> Bool {
        return nationalQueue.sync {
            return isStillValid(lastDownloadTimeStamp: self.nationalRulesStorage.lastNationalRulesListDownload, validDuration: self.nationalRulesStorage.nationalRulesList.validDuration)
        }
    }

    func updateNationalRules(_ update: NationalRulesList) -> Bool {
        return nationalQueue.sync {
            self.nationalRulesStorage.nationalRulesList = update
            self.nationalRulesStorage.lastNationalRulesListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            return self.nationalRulesSecureStorage.saveSynchronously(self.nationalRulesStorage)
        }
    }

    func nationalRules() -> NationalRulesList {
        return nationalQueue.sync {
            return self.nationalRulesStorage.nationalRulesList
        }
    }

    // MARK: - Validity

    private func isStillValid(lastDownloadTimeStamp: Int64, validDuration: Int64) -> Bool {
        let stillValidUntil = lastDownloadTimeStamp + validDuration
        let validUntilDate = Date(timeIntervalSince1970: Double(stillValidUntil) / 1000.0)
        return Date().isBefore(validUntilDate)
    }
}

class RevocationStorage: Codable {
    var revocationList = RevocationList()
    var lastRevocationListDownload: Int64 = 0
}

class ActiveCertificatesStorage: Codable {
    var activeCertificates: [TrustCertificate] = []
    var certificateSince: String = ""
    var certificateValidDuration: Int64 = 0
    var lastCertificateListDownload: Int64 = 0
}

class NationalRulesStorage: Codable {
    var nationalRulesList = NationalRulesList()
    var lastNationalRulesListDownload: Int64 = 0
}
