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
#if os(iOS)
    import UIKit
#endif

struct Endpoint {
    // MARK: - Implementation

    enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    let method: Method
    let url: URL
    let headers: [String: String]?
    let body: Data?
}

extension Endpoint {
    func request(timeoutInterval: TimeInterval = 30.0, reloadIgnoringLocalCache: Bool = false) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue

        if reloadIgnoringLocalCache {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }

        request.setValue(userAgentHeader, forHTTPHeaderField: "User-Agent")

        for (k, v) in headers ?? [:] {
            request.setValue(v, forHTTPHeaderField: k)
        }

        request.httpBody = body

        return request
    }

    private var userAgentHeader: String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let appVersion = Bundle.appVersion
        let build = Bundle.buildNumber

        var os = "unknown"
        var systemVersion = "unknown"
        #if os(iOS)
            os = "iOS"
            systemVersion = UIDevice.current.systemVersion
        #elseif os(macOS)
            os = "macOS"
            systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let header = [bundleIdentifier, appVersion, build, os, systemVersion].joined(separator: ";")
        return header
    }
}

extension HTTPURLResponse {
    func value(forHeaderField field: String) -> String? {
        if #available(iOS 13.0, macOS 10.15, *) {
            return self.value(forHTTPHeaderField: field)
        } else {
            for header in allHeaderFields {
                if let stringValue = header.value as? String,
                   let key = header.key as? String,
                   key.lowercased() == field.lowercased() {
                    return stringValue
                }
            }
            return nil
        }
    }
}
