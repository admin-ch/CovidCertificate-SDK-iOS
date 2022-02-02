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

@testable import CovidCertificateSDK
import Foundation

class TestTrustlistManager: TrustlistManagerProtocol {
    // MARK: - JWS verification

    static var jwsVerifier: JWSVerifier {
        guard let data = Bundle.module.url(forResource: "swiss_governmentrootcaii", withExtension: "der") else {
            fatalError("Signing CA not in Bundle")
        }
        guard let caPem = try? Data(contentsOf: data),
              let verifier = JWSVerifier(rootCertificate: caPem, leafCertMustMatch: TestTrustlistManager.leafCertificateCommonName) else {
            fatalError("Cannot create certificate from data")
        }
        return verifier
    }

    private static var leafCertificateCommonName: String {
        switch CovidCertificateSDK.currentEnvironment {
        case .dev:
            return "CH01-AppContentCertificate-ref"
        case .abn:
            return "CH01-AppContentCertificate-abn"
        case .prod:
            return "CH01-AppContentCertificate"
        }
    }

    var nationalRulesListUpdater: TrustListUpdate
    var revocationListUpdater: TrustListUpdate
    var trustCertificateUpdater: TrustListUpdate
    var trustStorage: TrustStorageProtocol

    init() {
        trustStorage = TestTrustStorage(publicKeys: StaticTestTrustList().publicKeys())
        revocationListUpdater = TestTrustListUpdate(trustStorage: trustStorage)
        trustCertificateUpdater = TestTrustListUpdate(trustStorage: trustStorage)
        nationalRulesListUpdater = TestTrustListUpdate(trustStorage: trustStorage)
    }

    init(publicKeys: [TrustCertificate]) {
        trustStorage = TestTrustStorage(publicKeys: publicKeys)
        revocationListUpdater = TestTrustListUpdate(trustStorage: trustStorage)
        trustCertificateUpdater = TestTrustListUpdate(trustStorage: trustStorage)
        nationalRulesListUpdater = TestTrustListUpdate(trustStorage: trustStorage)
    }

    func restartTrustListUpdate(completionHandler _: @escaping (() -> Void), updateTimeInterval _: TimeInterval) {}
}

class TestTrustListUpdate: TrustListUpdate {
    // MARK: - Update

    override func synchronousUpdate(ignoreLocalCache _: Bool = false) -> NetworkError? {
        // update active certificates service
        sleep(1)
        return nil
    }
}

class TestTrustStorage: TrustStorageProtocol {
    private let publicKeys: [TrustCertificate]
    public var revokedCerts: Set<String> = []
    public var nextSince: String?

    init(publicKeys: [TrustCertificate]) {
        self.publicKeys = publicKeys
    }

    // MARK: - Revocation list

    func revokedCertificates() -> Set<String> {
        revokedCerts
    }

    func updateRevocationList(_ list: RevocationList, nextSince: String) -> Bool {
        list.revokedCerts.forEach { revokedCerts.insert($0) }
        self.nextSince = nextSince
        return true
    }

    func revocationListIsValid() -> Bool {
        true
    }

    var revocationListNextSince: String? {
        nextSince
    }

    // MARK: - Active Certificates

    func activeCertificatePublicKeys() -> [TrustCertificate] {
        publicKeys
    }

    func updateCertificateList(_: TrustCertificates, since _: String) -> Bool {
        // do nothing
        true
    }

    func updateActiveCertificates(_: ActiveTrustCertificates) -> Bool {
        // do nothing
        true
    }

    func certificateSince() -> String {
        ""
    }

    func certificateListIsValid() -> Bool {
        true
    }

    // MARK: - National rules

    func nationalRulesListIsStillValid() -> Bool {
        true
    }

    func updateNationalRules(_: NationalRulesList) -> Bool {
        true
    }

    func nationalRules() -> NationalRulesList {
        let data = Bundle.module.url(forResource: "nationalrules", withExtension: "json")!
        let nationalRulesData = try? Data(contentsOf: data)
        let nationalRules = NationalRulesList()
        nationalRules.requestData = nationalRulesData!
        return nationalRules
    }
}

class StaticTestTrustList {
    // MARK: - RSA

    private var DEV_CERT: TrustCertificate = {
        let certificate = TrustCertificate(keyId: "mmrfzpMU6xc=", use: "sig", alg: "RS256")
        certificate.subjectPublicKeyInfo = "MIIBCgKCAQEA4uZO4/7tneZ3XD5OAiTyoANOohQZC+DzZ4YC0AoLnEO+Z3PcTialCuRKS1zHfujNPI0GGG09DRVVXdv+tcKNXFDt/nRU1zlWDGFf4/63l5RIjkWFD3JFKqR8IlcJjrYYxstuZs3May3SGQJ+kZaeH5GFZMRvE0waHqMxbfwakvjf8qyBXCrZ1WsK+XJf7iYbJS2dO1a5HnegxPuRA7Zz8ikO7QRzmSongqOlkejEaIkFjx7gLGTUsOrBPYa5sdZqinDwmnjtKi52HLWarMXs+t1MN4etIp7GE7/zarjBNxk1Efiiwl+RdcwJ2uVwfrgzxfv3/TekZF8IUykV2Geu3QIDAQAB"
        return certificate
    }()
    
    private var ABN_CERT: TrustCertificate = {
        let certificate = TrustCertificate(keyId: "JLxre3vSwyg=", use: "sig", alg: "RS256")
        certificate.subjectPublicKeyInfo = "MIIBCgKCAQEA0bVecdVEUBEaB6Uu8VtXrtVnN0Fa9+hAcO0XcjLgLVDB89Y4+huGO94Y93TY43x9eXRRWcNleacBR0OdzDpAUOfdUbvrw2nNSb5OhhKG+mHbuBaImWKpvima0BeK0Gid01IG8u83SKBOabU34WUn5m37mPj0YonqFOyjnyCE1wrnaeG95lh0ZC5WCUB2BqNI4ZZQXwDCCC5STka3l02ZNAIHMoHLmgqAqWbXXS5r41ltumbRRaVGu47pSURpzz/wCZep6HnmhNvOE/T5lNzlolxgcltKc7VZtcoZnK9JFkT7tk4GR2H4mnA1lxAHOkJOaEkZxT6Nrm5r8OvA0ybuMQIDAQAB"
        return certificate
    }()
    
    private var PROD_CERT: TrustCertificate = {
        let certificate = TrustCertificate(keyId: "Ll3NP03zOxY=", use: "sig", alg: "RS256")
        certificate.subjectPublicKeyInfo = "MIIBCgKCAQEAtk/51stJXU48RqD2lh4IdsxFrjlJfmTCrLr3cQNEXkrEoI3OEV8NnotE1RjVmQrqLTT04oxpWlcbMolXtJBtu3rOiLNwQvyVEbj/xSc6KT84Tp7GBo1P/kkunY+Vmab6HUCV/oGZYmsdiUP/OnTPX6Wy6delDhnrgHIDti73/TSsG7Zl1V6km7+KIkjAkVCEDkkUD7uffd4G+GBZ0B9F1KOT0IcFQNvDm0zlROVoGFlmPS8DWlrLHuIdMbB281uiDjcN+kNUt7rUyyj6TFgX9WCgEB/5mQBMRaaXK1zeDTaNkmC2S7IWxhMQsMBXJyAdbD9AnQOZc6XRjBauO7gz0wIDAQAB"
        return certificate
    }()
    
    func publicKeys() -> [TrustCertificate] {
        switch CovidCertificateSDK.currentEnvironment {
        case .dev:
            return [DEV_CERT]
        case .abn:
            return [ABN_CERT]
        case .prod:
            return [PROD_CERT]
        }
    }
}
