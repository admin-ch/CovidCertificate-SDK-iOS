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
    func updateRevocationHashes(_ hashes: RevocationHashes, nextSince: String) -> Bool
    func revocationHashesAreValid() -> Bool
    
    func revokedCertificates() -> Set<String>
    func updateRevocationList(_ list: RevocationList, nextSince: String) -> Bool
    var revocationListNextSince: String? { get }
    func revocationListIsValid() -> Bool
    func revocationHashIsValid(for holder: CertificateHolder) -> Bool


    func activeCertificatePublicKeys() -> [TrustCertificate]
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
    
    private let revocationDBManager = RevocationDBManager()

    private lazy var revocationHashesStorage = self.revocationDBManager.getAll() ?? RevocationHashesStorage()
    private lazy var revocationStorage = self.revocationSecureStorage.loadSynchronously() ?? RevocationStorage.getBundledStorage()
    private let revocationSecureStorage = SecureStorage<RevocationStorage>(name: "revocations")

    let revocationQueue = DispatchQueue(label: "storage.sync.revocation")
    let certificateQueue = DispatchQueue(label: "storage.sync.certificate")
    let nationalQueue = DispatchQueue(label: "storage.sync.national")

    // MARK: - Revocation List

    init() {
        // The name of the revocations secure storage was changes from "revocation" to "revocations"
        // This was done in order to ensure a complete revocation list
        // If the file of revocations before pre bundeling exists make sure to delete it
        // This makes sure we don't need twice the disk space for revocations in the worst case
        if let path = SecureStorage<RevocationStorage>(name: "revocation").path,
           FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.removeItem(atPath: path.path)
        }
    }

    func revokedCertificates() -> Set<String> {
        revocationQueue.sync {
            self.revocationStorage.revocationList.revokedCerts
        }
    }
    
    //This method adds all hashes of certificate (with a specific prefix) that are revoked into the DB
    func updateRevocationHashes(_ hashes: RevocationHashes, nextSince: String) -> Bool {
        revocationQueue.sync {
            hashes.hashFilters?.forEach { self.revocationHashesStorage.hashedRevocationList.append($0) }
            self.revocationHashesStorage.nextSince = nextSince
            self.revocationHashesStorage.expires = hashes.expires
            self.revocationHashesStorage.lastDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            return self.revocationDBManager.insert(hashes, nextSince)
        }
    }

    func updateRevocationList(_ list: RevocationList, nextSince: String) -> Bool {
        revocationQueue.sync {
            list.revokedCerts.forEach { self.revocationStorage.revocationList.revokedCerts.insert($0) }
            self.revocationStorage.revocationList.validDuration = list.validDuration
            self.revocationStorage.nextSince = nextSince
            self.revocationStorage.lastRevocationListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            return self.revocationSecureStorage.saveSynchronously(self.revocationStorage)
        }
    }
    
    func revocationHashesAreValid() -> Bool {
        revocationQueue.sync {
            isStillValid(lastDownloadTimeStamp: self.revocationHashesStorage.lastDownload, validDuration: self.revocationHashesStorage.expires)
        }
    }

    func revocationListIsValid() -> Bool {
        revocationQueue.sync {
            isStillValid(lastDownloadTimeStamp: self.revocationStorage.lastRevocationListDownload, validDuration: self.revocationStorage.revocationList.validDuration)
        }
    }
    
    //MARK: checks if a certain certificate is currently in the hash-DB and is not expired
    func revocationHashIsValid(for holder: CertificateHolder) -> Bool {
        revocationQueue.sync {
            let (lastDownload, validDuration) = revocationDBManager.checkSingleCert(holder)
            if let lastDownload = lastDownload, let validDuration = validDuration {
                return isStillValid(lastDownloadTimeStamp: lastDownload, validDuration: validDuration)
            } else {
                return true
            }
        }
    }

    var revocationListNextSince: String? {
        revocationQueue.sync {
            self.revocationStorage.nextSince
        }
    }

    // MARK: - Certificate List

    func updateCertificateList(_ update: TrustCertificates, since: String) -> Bool {
        // add all certificates from update
        certificateQueue.sync {
            self.activeCertificatesStorage.certificateSince = since
            self.activeCertificatesStorage.activeCertificates.append(contentsOf: update.certs)
            return self.activeCertificatesSecureStorage.saveSynchronously(self.activeCertificatesStorage)
        }
    }

    func updateActiveCertificates(_ activeCertificates: ActiveTrustCertificates) -> Bool {
        // remove all certificates that are not active
        certificateQueue.sync {
            self.activeCertificatesStorage.activeCertificates.removeAll { c in
                !activeCertificates.activeKeyIds.contains(c.keyId)
            }

            self.activeCertificatesStorage.lastCertificateListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            self.activeCertificatesStorage.certificateValidDuration = activeCertificates.validDuration

            return self.activeCertificatesSecureStorage.saveSynchronously(self.activeCertificatesStorage)
        }
    }

    func activeCertificatePublicKeys() -> [TrustCertificate] {
        certificateQueue.sync {
            self.activeCertificatesStorage.activeCertificates
        }
    }

    func certificateSince() -> String {
        certificateQueue.sync {
            self.activeCertificatesStorage.certificateSince
        }
    }

    func certificateListIsValid() -> Bool {
        certificateQueue.sync {
            isStillValid(lastDownloadTimeStamp: self.activeCertificatesStorage.lastCertificateListDownload, validDuration: self.activeCertificatesStorage.certificateValidDuration)
        }
    }

    // MARK: - National rules

    func nationalRulesListIsStillValid() -> Bool {
        nationalQueue.sync {
            isStillValid(lastDownloadTimeStamp: self.nationalRulesStorage.lastNationalRulesListDownload, validDuration: self.nationalRulesStorage.nationalRulesList.validDuration)
        }
    }

    func updateNationalRules(_ update: NationalRulesList) -> Bool {
        nationalQueue.sync {
            self.nationalRulesStorage.nationalRulesList = update
            self.nationalRulesStorage.lastNationalRulesListDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            return self.nationalRulesSecureStorage.saveSynchronously(self.nationalRulesStorage)
        }
    }

    func nationalRules() -> NationalRulesList {
        nationalQueue.sync {
            self.nationalRulesStorage.nationalRulesList
        }
    }

    // MARK: - Validity

    private func isStillValid(lastDownloadTimeStamp: Int64, validDuration: Int64) -> Bool {
        let stillValidUntil = lastDownloadTimeStamp + validDuration
        let validUntilDate = Date(timeIntervalSince1970: Double(stillValidUntil) / 1000.0)
        return Date().isBefore(validUntilDate)
    }
}

class RevocationHashesStorage: Codable {
    var hashedRevocationList = [HashFilter]()
    var lastDownload: Int64 = 0
    var expires: Int64 = 0
    var nextSince: String?
}

class RevocationStorage: Codable {
    var revocationList = RevocationList()
    var lastRevocationListDownload: Int64 = 0
    var nextSince: String?
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

extension RevocationStorage {
    static func getBundledStorage(environment: SDKEnvironment = CovidCertificateSDK.currentEnvironment) -> RevocationStorage {
        // only the prod revocations are pre-packaged
        guard environment == .prod,
              let resource = Bundle.module.path(forResource: "revocations", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: resource), options: .mappedIfSafe),
              let bundled = try? JSONDecoder().decode(RevocationStorage.self, from: data)
        else {
            // if unabled to read use a empty storage
            return RevocationStorage()
        }
        return bundled
    }
}
