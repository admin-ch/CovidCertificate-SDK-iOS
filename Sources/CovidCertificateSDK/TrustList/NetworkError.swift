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
    case NETWORK_ERROR_TIMED_OUT
    case NETWORK_ERROR_CANNOT_FIND_HOST
    case NETWORK_ERROR_CANNOT_CONNECT_TO_HOST
    case NETWORK_ERROR_CONNECTION_LOST
    case NETWORK_ERROR_DNS_LOOKUP_FAILURE
    case NETWORK_ERROR_INTERNATIONAL_ROAMING_OFF
    case NETWORK_ERROR_DATA_NOT_ALLOWED

    public var message: String {
        switch self {
        case .NETWORK_ERROR: return "A network error occured"
        case .NETWORK_PARSE_ERROR: return "The data could not be parsed"
        case .NETWORK_NO_INTERNET_CONNECTION,
             .NETWORK_ERROR_TIMED_OUT,
             .NETWORK_ERROR_CANNOT_FIND_HOST,
             .NETWORK_ERROR_CANNOT_CONNECT_TO_HOST,
             .NETWORK_ERROR_CONNECTION_LOST,
             .NETWORK_ERROR_DNS_LOOKUP_FAILURE,
             .NETWORK_ERROR_INTERNATIONAL_ROAMING_OFF,
             .NETWORK_ERROR_DATA_NOT_ALLOWED:
            return "The internet connection appears to be offline"
        }
    }

    public var errorCode: String {
        switch self {
        case let .NETWORK_ERROR(code): return code.count > 0 ? "NE|\(code)" : "NE"
        case .NETWORK_PARSE_ERROR: return "NE|PE"
        case .NETWORK_NO_INTERNET_CONNECTION: return "NE|NIC"
        case .NETWORK_ERROR_TIMED_OUT: return "NE|TIO"
        case .NETWORK_ERROR_CANNOT_FIND_HOST: return "NE|CFH"
        case .NETWORK_ERROR_CANNOT_CONNECT_TO_HOST: return "NE|CTH"
        case .NETWORK_ERROR_CONNECTION_LOST: return "NE|CNL"
        case .NETWORK_ERROR_DNS_LOOKUP_FAILURE: return "NE|DLF"
        case .NETWORK_ERROR_INTERNATIONAL_ROAMING_OFF: return "NE|IRO"
        case .NETWORK_ERROR_DATA_NOT_ALLOWED: return "NE|DNA"
        }
    }
}

extension Error {
    func asNetworkError() -> NetworkError {
        guard let e = self as? URLError else {
            return .NETWORK_ERROR(errorCode: "")
        }

        switch e.errorCode {
        case -1001: return .NETWORK_ERROR_TIMED_OUT
        case -1003: return .NETWORK_ERROR_CANNOT_FIND_HOST
        case -1004: return .NETWORK_ERROR_CANNOT_CONNECT_TO_HOST
        case -1005: return .NETWORK_ERROR_CONNECTION_LOST
        case -1006: return .NETWORK_ERROR_DNS_LOOKUP_FAILURE
        case -1009: return .NETWORK_NO_INTERNET_CONNECTION
        case -1018: return .NETWORK_ERROR_INTERNATIONAL_ROAMING_OFF
        case -1020: return .NETWORK_ERROR_DATA_NOT_ALLOWED
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
        case .NETWORK_NO_INTERNET_CONNECTION,
             .NETWORK_ERROR_TIMED_OUT,
             .NETWORK_ERROR_CANNOT_FIND_HOST,
             .NETWORK_ERROR_CANNOT_CONNECT_TO_HOST,
             .NETWORK_ERROR_CONNECTION_LOST,
             .NETWORK_ERROR_DNS_LOOKUP_FAILURE,
             .NETWORK_NO_INTERNET_CONNECTION,
             .NETWORK_ERROR_INTERNATIONAL_ROAMING_OFF,
             .NETWORK_ERROR_DATA_NOT_ALLOWED:
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
        case .NETWORK_NO_INTERNET_CONNECTION,
             .NETWORK_ERROR_TIMED_OUT,
             .NETWORK_ERROR_CANNOT_FIND_HOST,
             .NETWORK_ERROR_CANNOT_CONNECT_TO_HOST,
             .NETWORK_ERROR_CONNECTION_LOST,
             .NETWORK_ERROR_DNS_LOOKUP_FAILURE,
             .NETWORK_NO_INTERNET_CONNECTION,
             .NETWORK_ERROR_INTERNATIONAL_ROAMING_OFF,
             .NETWORK_ERROR_DATA_NOT_ALLOWED:
            return .NETWORK_NO_INTERNET_CONNECTION
        }
    }
}
