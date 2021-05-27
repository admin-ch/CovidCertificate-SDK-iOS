//
//  Extensions.swift
//
//
//  Created by Dominik Mocher on 14.04.21.
//
// changed isBefore and isAfter to allow Targets below ios13
//

import Foundation

extension Data {
    func humanReadable() -> String {
        return map { String(format: "%02x ", $0) }.joined()
    }

    public var bytes: [UInt8] {
        return [UInt8](self)
    }

    func base64UrlEncodedString() -> String {
        return base64EncodedString(options: .endLineWithLineFeed)
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

extension Date {
    func isBefore(_ otherDate: Date) -> Bool {
        self < otherDate
    }

    func isAfter(_ otherDate: Date) -> Bool {
        self > otherDate
    }
}

extension EuHealthCert {
    func certIdentifiers() -> [String] {
        switch certType {
        case .vaccination:
            return vaccinations!.map { vac in
                vac.certificateIdentifier
            }
        case .recovery:
            return pastInfections!.map { rec in
                rec.certificateIdentifier
            }
        case .test:
            return tests!.map { test in
                test.certificateIdentifier
            }
        default:
            return []
        }
    }
}
