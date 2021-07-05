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
import UIKit

class MetadataManager {

    // MARK: - Shared instance

    static let shared = MetadataManager()

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }


    @UBUserDefault(key: "covidcertififcate.metadata.covidcertififcate.current", defaultValue: fallbackMetadata)
    static var currentMetadata: MetadataReponse

    @UBUserDefault(key: "covidcertififcate.metadata.lastLoad", defaultValue: nil)
    static var lastLoad: Date?

    static let foregroundValidityInterval: TimeInterval = 60 * 60 * 1 // 1h

    var jwsVerifier: JWSVerifier {
        guard let data = Bundle.module.url(forResource: "swiss_governmentrootcaii", withExtension: "der") else {
            fatalError("Signing CA not in Bundle")
        }
        guard let caPem = try? Data(contentsOf: data),
              let verifier = JWSVerifier(rootCertificate: caPem, leafCertMustMatch: Self.leafCertificateCommonName) else {
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

    @objc func applicationDidBecomeActive() {
        load()
    }

    static func shouldLoad(lastLoad: Date?) -> Bool {
        return lastLoad == nil || Date().timeIntervalSince(lastLoad!) > Self.foregroundValidityInterval
    }

    func load() {
        let request = CovidCertificateSDK.currentEnvironment.metadata().request()

        guard Self.shouldLoad(lastLoad: Self.lastLoad)
        else {
            return
        }

        URLSession.certificatePinned.dataTask(with: request, completionHandler: { data, response, error in
            guard let _ = response as? HTTPURLResponse,
                  let data = data
            else {
                return
            }

            self.jwsVerifier.verifyAndDecode(httpBody: data) { (result: Result<MetadataReponse, JWSError>) in
                if case let .success(metadata) = result {
                    Self.currentMetadata = metadata
                    Self.lastLoad = Date()
                }
            }
        }).resume()
    }


    // In case the metadata has not yet been loaded at least once from the request, we use the bundled metadata as fallback
    private static var fallbackMetadata: MetadataReponse {
        guard let resource = Bundle.module.path(forResource: "products_metadata", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: resource), options: .mappedIfSafe),
              let config = try? JSONDecoder().decode(MetadataReponse.self, from: data)
        else {
            fatalError()
        }
        return config
    }
}
