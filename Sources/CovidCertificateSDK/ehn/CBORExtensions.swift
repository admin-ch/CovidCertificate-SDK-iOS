//
//  CBORExtensions.swift
//
//
//  Created by Dominik Mocher on 14.04.21.
//

import Foundation
import SwiftCBOR

extension CBOR {
    func unwrap() -> Any? {
        switch self {
        case let .simple(value): return value
        case let .boolean(value): return value
        case let .byteString(value): return value
        case let .date(value): return value
        case let .double(value): return value
        case let .float(value): return value
        case let .half(value): return value
        case let .tagged(tag, cbor): return (tag, cbor)
        case let .array(array): return array
        case let .map(map): return map
        case let .utf8String(value): return value
        case let .negativeInt(value): return value
        case let .unsignedInt(value): return value
        default:
            return nil
        }
    }

    func asUInt64() -> UInt64? {
        return unwrap() as? UInt64
    }

    func asInt64() -> Int64? {
        return unwrap() as? Int64
    }

    func asString() -> String? {
        return unwrap() as? String
    }

    func asList() -> [CBOR]? {
        return unwrap() as? [CBOR]
    }

    func asMap() -> [CBOR: CBOR]? {
        return unwrap() as? [CBOR: CBOR]
    }

    func asBytes() -> [UInt8]? {
        return unwrap() as? [UInt8]
    }

    func asData() -> Data {
        return Data(encode())
    }

    func asCose() -> (CBOR.Tag, [CBOR])? {
        guard let rawCose = unwrap() as? (CBOR.Tag, CBOR),
              let cosePayload = rawCose.1.asList() else {
            return nil
        }
        return (rawCose.0, cosePayload)
    }

    func decodeBytestring() -> CBOR? {
        guard let bytestring = asBytes(),
              let decoded = try? CBORDecoder(input: bytestring).decodeItem() else {
            return nil
        }
        return decoded
    }
}

public extension CBOR.Tag {
    static let coseSign1Item = CBOR.Tag(rawValue: 18)
    static let coseSignItem = CBOR.Tag(rawValue: 98)
}

extension Dictionary where Key == CBOR {
    subscript<Index: RawRepresentable>(index: Index) -> Value? where Index.RawValue == String {
        return self[CBOR(stringLiteral: index.rawValue)]
    }

    subscript<Index: RawRepresentable>(index: Index) -> Value? where Index.RawValue == Int {
        return self[CBOR(integerLiteral: index.rawValue)]
    }
}
