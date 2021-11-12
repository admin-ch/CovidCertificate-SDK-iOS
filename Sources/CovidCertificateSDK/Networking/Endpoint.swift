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
    func request(timeoutInterval: TimeInterval = 10.0, reloadRevalidatingCacheData: Bool = false) -> URLRequest {
        var cachePolicy: URLRequest.CachePolicy?

        if reloadRevalidatingCacheData {
            if #available(iOS 13, *) {
                // Add "If-None-Match" header with Etag from cache
                // This will return HTTP 304 from server if nothing changed
                cachePolicy = .reloadRevalidatingCacheData
            } else {
                cachePolicy = .reloadIgnoringLocalCacheData
            }
        }

        return request(timeoutInterval: timeoutInterval, cachePolicy: cachePolicy)
    }

    func request(timeoutInterval: TimeInterval = 10.0, reloadIgnoringLocalCache: Bool = false) -> URLRequest {
        request(timeoutInterval: timeoutInterval, cachePolicy: reloadIgnoringLocalCache ? .reloadIgnoringLocalCacheData : nil)
    }

    func request(timeoutInterval: TimeInterval = 10.0, cachePolicy: URLRequest.CachePolicy?) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue

        if let cacheRequestPolicy = cachePolicy {
            request.cachePolicy = cacheRequestPolicy
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

    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var date: Date? {
        guard let string = value(forHeaderField: "date") else { return nil }
        return HTTPURLResponse.dateFormatter.date(from: string)
    }

    var age: TimeInterval {
        guard let string = value(forHeaderField: "Age") else { return 0 }
        return TimeInterval(string) ?? 0
    }
}
