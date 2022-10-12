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

    /* func testUpdate() {
           let storage = TrustStorage()
           var lastNextSince: String?
           let revs = (0 ... 100).map(String.init)
           let session = MockSession { request in
               URLComponents(url: request.url!, resolvingAgainstBaseURL: true)?.queryItems?.forEach { item in
                   if item.name == "since", lastNextSince != nil {
                       XCTAssertEqual(item.value, lastNextSince)
                   }
               }

               let since: Int = lastNextSince == nil ? 0 : Int(lastNextSince!)!
               let nextSince = min(since + (revs.count / 20), revs.count)
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
           for i in 0 ... revs.count / (revs.count / 20) {
               XCTAssert(storage.isCertificateRevoced(uvci: revs[i * (revs.count / 20)]))
           }
           XCTAssertEqual(session.requests.count, 20)
       }

      func testUpdateEmptyList() {
          let storage = TrustStorage()
          let session = MockSession { request in
              var since: String = ""
              URLComponents(url: request.url!, resolvingAgainstBaseURL: true)?.queryItems?.forEach { item in
                  if item.name == "since" {
                      since = item.value ?? ""
                  }
              }

              let list = RevocationList()
              list.revokedCerts = Set<String>()
              let data = try! JSONEncoder().encode(list)
              let httpResponse = HTTPURLResponse(url: URL(string: "http://ubique.ch")!, statusCode: 200, httpVersion: nil, headerFields: [
                  "up-to-date": "true",
                  "x-next-since": since,
              ])
              return (data, httpResponse, nil)
          }
          let update = RevocationListUpdate(trustStorage: storage, decoder: RevocationListJSONDecoder(), session: session)
          _ = update.synchronousUpdate()
      }

     func testPrePackagedDecoding() {
         let storage = RevocationStorage(enviroment: .prod)

         XCTAssertNotNil(storage.nextSince)
         XCTAssertNotEqual(storage.lastDownload, 0)
         XCTAssertNotEqual(storage.validDuration, 0)
     }*/
}

class RevocationListJSONDecoder: RevocationListDecoder {
    func decode(_ data: Data) -> RevocationList? {
        try? JSONDecoder().decode(RevocationList.self, from: data)
    }
}
