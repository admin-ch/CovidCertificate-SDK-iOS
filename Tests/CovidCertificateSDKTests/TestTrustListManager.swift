//
//  File.swift
//  
//
//  Created by Marco Zimmermann on 08.06.21.
//

import Foundation
@testable import CovidCertificateSDK

class TestTrustlistManager : TrustlistManagerProtocol {
    var nationalRulesListUpdater: TrustListUpdate
    var revocationListUpdater: TrustListUpdate
    var trustCertificateUpdater: TrustListUpdate
    var trustStorage: TrustStorageProtocol

    init() {
        self.trustStorage = TestTrustStorage(publicKeys: StaticTestTrustList().publicKeys())
        self.revocationListUpdater = TestTrustListUpdate(trustStorage: self.trustStorage)
        self.trustCertificateUpdater = TestTrustListUpdate(trustStorage: self.trustStorage)
        self.nationalRulesListUpdater = TestTrustListUpdate(trustStorage: self.trustStorage)
    }

    init(publicKeys: [TrustListPublicKey]) {
        self.trustStorage = TestTrustStorage(publicKeys: publicKeys)
        self.revocationListUpdater = TestTrustListUpdate(trustStorage: self.trustStorage)
        self.trustCertificateUpdater = TestTrustListUpdate(trustStorage: self.trustStorage)
        self.nationalRulesListUpdater = TestTrustListUpdate(trustStorage: self.trustStorage)
    }

    func restartTrustListUpdate(completionHandler: @escaping (() -> ()), updateTimeInterval: TimeInterval) {

    }
}


class TestTrustListUpdate : TrustListUpdate {
    // MARK: - Update

    internal override func synchronousUpdate() -> NetworkError? {
        // update active certificates service
        sleep(1)
        return nil
    }
}

class TestTrustStorage : TrustStorageProtocol {

    private let publicKeys : [TrustListPublicKey]

    init(publicKeys: [TrustListPublicKey]) {
        self.publicKeys = publicKeys
    }

    // MARK: - Revocation list

    func revokedCertificates() -> [String] {
        return []
    }

    func updateRevocationList(_ list: RevocationList) -> Bool {
        // do nothing
        return true
    }

    func revocationListIsValid() -> Bool {
        return true
    }

    // MARK: - Active Certificates

    func activeCertificatePublicKeys() -> [TrustListPublicKey] {
        return self.publicKeys
    }

    func updateCertificateList(_ update: TrustCertificates, since: Int64) -> Bool {
        // do nothing
        return true
    }

    func updateActiveCertificates(_ activeCertificates: ActiveTrustCertificates) -> Bool {
        // do nothing
        return true
    }

    func certificateSince() -> Int64 {
        return 0
    }

    func certificateListIsValid() -> Bool {
        return true
    }

    // MARK: - National rules

    func nationalRulesListIsStillValid() -> Bool {
        return true
    }

    func updateNationalRules(_ update: NationalRulesList) -> Bool {
        return true
    }

    func nationalRules() -> NationalRulesList {
        return NationalRulesList()
    }
}

class StaticTestTrustList {
    // MARK: - RSA

    private let DEV_RSA_ASN1_DER = "MIIBCgKCAQEA4uZO4/7tneZ3XD5OAiTyoANOohQZC+DzZ4YC0AoLnEO+Z3PcTialCuRKS1zHfujNPI0GGG09DRVVXdv+tcKNXFDt/nRU1zlWDGFf4/63l5RIjkWFD3JFKqR8IlcJjrYYxstuZs3May3SGQJ+kZaeH5GFZMRvE0waHqMxbfwakvjf8qyBXCrZ1WsK+XJf7iYbJS2dO1a5HnegxPuRA7Zz8ikO7QRzmSongqOlkejEaIkFjx7gLGTUsOrBPYa5sdZqinDwmnjtKi52HLWarMXs+t1MN4etIp7GE7/zarjBNxk1Efiiwl+RdcwJ2uVwfrgzxfv3/TekZF8IUykV2Geu3QIDAQAB"
    private let ABN_RSA_ASN1_DER = "MIIBCgKCAQEA0bVecdVEUBEaB6Uu8VtXrtVnN0Fa9+hAcO0XcjLgLVDB89Y4+huGO94Y93TY43x9eXRRWcNleacBR0OdzDpAUOfdUbvrw2nNSb5OhhKG+mHbuBaImWKpvima0BeK0Gid01IG8u83SKBOabU34WUn5m37mPj0YonqFOyjnyCE1wrnaeG95lh0ZC5WCUB2BqNI4ZZQXwDCCC5STka3l02ZNAIHMoHLmgqAqWbXXS5r41ltumbRRaVGu47pSURpzz/wCZep6HnmhNvOE/T5lNzlolxgcltKc7VZtcoZnK9JFkT7tk4GR2H4mnA1lxAHOkJOaEkZxT6Nrm5r8OvA0ybuMQIDAQAB"
    private let PROD_RSA_ASN1_DER = "MIIBCgKCAQEAtk/51stJXU48RqD2lh4IdsxFrjlJfmTCrLr3cQNEXkrEoI3OEV8NnotE1RjVmQrqLTT04oxpWlcbMolXtJBtu3rOiLNwQvyVEbj/xSc6KT84Tp7GBo1P/kkunY+Vmab6HUCV/oGZYmsdiUP/OnTPX6Wy6delDhnrgHIDti73/TSsG7Zl1V6km7+KIkjAkVCEDkkUD7uffd4G+GBZ0B9F1KOT0IcFQNvDm0zlROVoGFlmPS8DWlrLHuIdMbB281uiDjcN+kNUt7rUyyj6TFgX9WCgEB/5mQBMRaaXK1zeDTaNkmC2S7IWxhMQsMBXJyAdbD9AnQOZc6XRjBauO7gz0wIDAQAB"

    func publicKeys() -> [TrustListPublicKey] {
        switch CovidCertificateSDK.currentEnvironment {
        case .dev:
            return [TrustListPublicKey(keyId: "mmrfzpMU6xc=", withRsaKey: DEV_RSA_ASN1_DER)].compactMap{ $0 }
        case .abn:
            return [TrustListPublicKey(keyId: "JLxre3vSwyg=", withRsaKey: ABN_RSA_ASN1_DER)].compactMap{ $0 }
        case .prod:
            return [TrustListPublicKey(keyId: "Ll3NP03zOxY=", withRsaKey: PROD_RSA_ASN1_DER)].compactMap{ $0 }
        }
    }
}
