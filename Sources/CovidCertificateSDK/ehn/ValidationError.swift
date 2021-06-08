//
//  ValidationError.swift
//
//
//  Created by Dominik Mocher on 07.04.21.
//

import Foundation

public enum SignatureTypeInvalidError: Error, Equatable {
    case CWT_HEADER_PARSE_ERROR
    case CERT_TYPE_AMBIGUOUS

    public var message: String {
        switch self {
        case .CERT_TYPE_AMBIGUOUS: return "The certificate type could not be determined"
        case .CWT_HEADER_PARSE_ERROR: return "The CWT exp/iat headers could not be parsed"
        }
    }

    public var errorCode: String {
        switch self {
        case .CERT_TYPE_AMBIGUOUS: return "CTA"
        case .CWT_HEADER_PARSE_ERROR: return "HPE"
        }
    }
}

public enum ValidationError: Error, Equatable {
    case GENERAL_ERROR
    case CBOR_DESERIALIZATION_FAILED
    case CERTIFICATE_QUERY_FAILED
    case USER_CANCELLED
    case TRUST_SERVICE_ERROR(cause: String)
    case KEY_NOT_IN_TRUST_LIST
    case PUBLIC_KEY_EXPIRED
    case CWT_EXPIRED
    case ISSUED_IN_FUTURE
    case UNSUITABLE_PUBLIC_KEY_TYPE
    case KEY_CREATION_ERROR
    case KEYSTORE_ERROR(cause: String)
    case REVOKED
    case SIGNATURE_TYPE_INVALID(SignatureTypeInvalidError)
    case NETWORK_ERROR
    case NETWORK_PARSE_ERROR

    public var message: String {
        switch self {
        case .GENERAL_ERROR: return "General error"
        case .CBOR_DESERIALIZATION_FAILED: return "CBOR deserialization failed"
        case .CERTIFICATE_QUERY_FAILED: return "Signing certificate query failed"
        case .USER_CANCELLED: return "User cancelled"
        case let .TRUST_SERVICE_ERROR(cause): return cause
        case .KEY_NOT_IN_TRUST_LIST: return "Key not in trust list"
        case .PUBLIC_KEY_EXPIRED: return "Public key expired"
        case .UNSUITABLE_PUBLIC_KEY_TYPE: return "Key unsuitable for EHN certificate type"
        case .KEY_CREATION_ERROR: return "Cannot create key from data"
        case let .KEYSTORE_ERROR(cause): return cause
        case .CWT_EXPIRED: return "The CWT expiary date has been reached"
        case .ISSUED_IN_FUTURE: return "The CWT was issued in the future"
        case .REVOKED: return "Certificate was revoked"
        case .SIGNATURE_TYPE_INVALID: return "The certificate is not valid according to specification"
        case .NETWORK_ERROR: return ""
        case .NETWORK_PARSE_ERROR: return ""
        }
    }

    public var errorCode: String {
        switch self {
        case .GENERAL_ERROR: return "GE"
        case .CBOR_DESERIALIZATION_FAILED: return ""
        case .CERTIFICATE_QUERY_FAILED: return ""
        case .USER_CANCELLED: return ""
        case .TRUST_SERVICE_ERROR: return "R|TSE"
        case .KEY_NOT_IN_TRUST_LIST: return "S|KNTL"
        case .PUBLIC_KEY_EXPIRED: return "R|PKE"
        case .UNSUITABLE_PUBLIC_KEY_TYPE: return "S|PKT"
        case .KEY_CREATION_ERROR: return ""
        case .KEYSTORE_ERROR: return ""
        case .CWT_EXPIRED: return "S|CWTE"
        case .ISSUED_IN_FUTURE: return ""
        case .REVOKED: return "R|REV"
        case let .SIGNATURE_TYPE_INVALID(wrapped): return "S|TIV|" + wrapped.errorCode
        case .NETWORK_ERROR: return "NOCONN"
        case .NETWORK_PARSE_ERROR: return "PE"
        }
    }
}
