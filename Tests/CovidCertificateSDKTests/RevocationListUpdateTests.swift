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
import XCTest

final class RevocationListUpdateTests: XCTestCase {
    override func setUp() {
        if !CovidCertificateSDK.isInitialized {
            CovidCertificateSDK.initialize(environment: .dev, apiKey: "")
        }
    }

    func testUpdate() {
        let storage = TestTrustStorage(publicKeys: [])
        storage.revokedCerts.insert("a")
        storage.revokedCerts.insert("b")
        storage.revokedCerts.insert("c")
        var lastNextSince: String?
        let revs = (0 ... 100_000).map(String.init)
        let session = MockSession { request in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: true)?.queryItems?.forEach { item in
                if item.name == "since" {
                    XCTAssertEqual(item.value, lastNextSince)
                }
            }

            let since: Int = lastNextSince == nil ? 0 : Int(lastNextSince!)!
            let nextSince = min(since + 5000, revs.count)
            let list = RevocationList()
            list.revokedCerts = Set<String>(revs[since ... nextSince])
            let data = try! JSONEncoder().encode(list)
            let httpResponse = HTTPURLResponse(url: URL(string: "http://ubique.ch")!, statusCode: 200, httpVersion: nil, headerFields: [
                "up-to-date": nextSince == revs.count ? "true" : "false",
                "x-next-since": String(nextSince),
            ])
            lastNextSince = String(nextSince)
            return (data, httpResponse, nil)
        }
        let update = RevocationListUpdate(trustStorage: storage, decoder: RevocationListJSONDecoder(), session: session)
        _ = update.synchronousUpdate()
        XCTAssertEqual(storage.nextSince, "100000")
        XCTAssertEqual(storage.revokedCertificates(), Set<String>(revs + ["a", "b", "c"]))
        XCTAssertEqual(session.requests.count, 20)
    }

    func testPrePackagedDecoding() {
        let storage = RevocationStorage.getBundledStorage(environment: .prod)
        XCTAssertEqual(storage.nextSince, "11743455")
        XCTAssertEqual(storage.lastRevocationListDownload, 1_641_452_551_535)
        XCTAssertEqual(storage.revocationList.validDuration, 172_800_000)
        XCTAssertEqual(storage.revocationList.revokedCerts.count, 353_501)
    }
}

class RevocationListJSONDecoder: RevocationListDecoder {
    func decode(_ data: Data) -> RevocationList? {
        try? JSONDecoder().decode(RevocationList.self, from: data)
    }
}
