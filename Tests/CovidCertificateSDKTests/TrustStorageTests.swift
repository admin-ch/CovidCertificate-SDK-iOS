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
import XCTest

final class TrustStorageTests: XCTestCase {
    func testFiltering() {
        let trustStorage = TrustStorage()
        let certificates = TrustCertificates()
        let json = """
                    [
                        {
                        "keyId": "keyid123",
                        "use": "t",
                        "alg": "RS256",
                        "subjectPublicKeyInfo": "\(randKey)"
                        }
                    ]
        """
        certificates.certs = try! JSONDecoder().decode([TrustCertificate].self, from: json.data(using: .utf8)!)
        _ = trustStorage.updateCertificateList(certificates, since: "")
        let emptyActiveCerts = trustStorage.activeCertificatePublicKeys().filter { $0.containsUse(trustListUseFilters: ["a"]) }
        XCTAssert(emptyActiveCerts.isEmpty)
        let activeCerts = trustStorage.activeCertificatePublicKeys().filter { $0.containsUse(trustListUseFilters: ["t"]) }
        XCTAssert(!activeCerts.isEmpty)
        XCTAssertEqual(activeCerts.first!.keyId, "keyid123")
    }

    func testFilteringMultiple() {
        let trustStorage = TrustStorage()
        let certificates = TrustCertificates()
        let json = """
                    [
                        {
                        "keyId": "keyid123",
                        "use": "tvr",
                        "alg": "RS256",
                        "subjectPublicKeyInfo": "\(randKey)"
                        },
                        {
                        "keyId": "keyidLight",
                        "use": "l",
                        "alg": "RS256",
                        "subjectPublicKeyInfo": "\(randKey)"
                        }
                    ]
        """
        certificates.certs = try! JSONDecoder().decode([TrustCertificate].self, from: json.data(using: .utf8)!)
        _ = trustStorage.updateCertificateList(certificates, since: "")

        let activeCerts = trustStorage.activeCertificatePublicKeys().filter { $0.containsUse(trustListUseFilters: CertificateType.dccCert.trustListUseFilters)}
        XCTAssert(!activeCerts.isEmpty)
        XCTAssert(activeCerts.count == 1)
        XCTAssertEqual(activeCerts.first!.keyId, "keyid123")

        let activeLightCerts = trustStorage.activeCertificatePublicKeys().filter { $0.containsUse(trustListUseFilters: CertificateType.lightCert.trustListUseFilters)}
        XCTAssert(!activeLightCerts.isEmpty)
        XCTAssert(activeLightCerts.count == 1)
        XCTAssertEqual(activeLightCerts.first!.keyId, "keyidLight")
    }

    private let randKey = "MIIBCgKCAQEA4uZO4/7tneZ3XD5OAiTyoANOohQZC+DzZ4YC0AoLnEO+Z3PcTialCuRKS1zHfujNPI0GGG09DRVVXdv+tcKNXFDt/nRU1zlWDGFf4/63l5RIjkWFD3JFKqR8IlcJjrYYxstuZs3May3SGQJ+kZaeH5GFZMRvE0waHqMxbfwakvjf8qyBXCrZ1WsK+XJf7iYbJS2dO1a5HnegxPuRA7Zz8ikO7QRzmSongqOlkejEaIkFjx7gLGTUsOrBPYa5sdZqinDwmnjtKi52HLWarMXs+t1MN4etIp7GE7/zarjBNxk1Efiiwl+RdcwJ2uVwfrgzxfv3/TekZF8IUykV2Geu3QIDAQAB"
}
