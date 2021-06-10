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

public enum NetworkError: Error, Equatable {
    case NETWORK_ERROR(errorCode: String)
    case NETWORK_PARSE_ERROR
    case NETWORK_NO_INTERNET_CONNECTION

    public var message: String {
        switch self {
        case .NETWORK_ERROR: return "A network error occured"
        case .NETWORK_PARSE_ERROR: return "The data could not be parsed"
        case .NETWORK_NO_INTERNET_CONNECTION: return "The internet connection appears to be offline"
        }
    }

    public var errorCode: String {
        switch self {
        case let .NETWORK_ERROR(code): return code.count > 0 ? "NE|\(code)" : "NE"
        case .NETWORK_PARSE_ERROR: return "NE|PE"
        case .NETWORK_NO_INTERNET_CONNECTION: return "NE|NIC"
        }
    }
}

extension Error {
    func asNetworkError() -> NetworkError {
        guard let e = self as? URLError else {
            return .NETWORK_ERROR(errorCode: "")
        }

        switch e.errorCode {
        case -1009: return .NETWORK_NO_INTERNET_CONNECTION
        default:
            return .NETWORK_ERROR(errorCode: "\(e.errorCode)")
        }
    }
}

extension NetworkError {
    func asValidationError() -> ValidationError {
        switch self {
        case let .NETWORK_ERROR(errorCode: errorCode):
            return .NETWORK_ERROR(errorCode: errorCode)
        case .NETWORK_PARSE_ERROR:
            return .NETWORK_PARSE_ERROR
        case .NETWORK_NO_INTERNET_CONNECTION:
            return .NETWORK_NO_INTERNET_CONNECTION
        }
    }
}

extension NetworkError {
    func asNationalRulesError() -> NationalRulesError {
        switch self {
        case let .NETWORK_ERROR(errorCode: errorCode):
            return .NETWORK_ERROR(errorCode: errorCode)
        case .NETWORK_PARSE_ERROR:
            return .NETWORK_PARSE_ERROR
        case .NETWORK_NO_INTERNET_CONNECTION:
            return .NETWORK_NO_INTERNET_CONNECTION
        }
    }
}
