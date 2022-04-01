//
//  Extensions.swift
//
//
//  Created by Dominik Mocher on 14.04.21.
//
// changed isBefore and isAfter to allow Targets below ios13
//

import Foundation
import SwiftCBOR

extension Data {
    func humanReadable() -> String {
        map { String(format: "%02x ", $0) }.joined()
    }

    var bytes: [UInt8] {
        [UInt8](self)
    }

    func base64UrlEncodedString() -> String {
        base64EncodedString(options: .endLineWithLineFeed)
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

extension Optional where Wrapped: Collection {
    /// Check if this optional array is nil or empty
    func isNilOrEmpty() -> Bool {
        // if self is nil `self?.isEmpty` is nil and hence the value after the ?? operator is used
        // otherwise self!.isEmpty checks for an empty array
        self?.isEmpty ?? true
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

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
    
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(count, r.lowerBound)),
                                            upper: min(count, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }

}

extension DCCCert {
    func certIdentifiers() -> [String] {
        switch immunisationType {
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


extension CertificateHolder {
    //MARK: - Hashes for revocation search
    //Heavily inspired by: https://github.com/eu-digital-green-certificates/dgca-app-core-ios/blob/main/Sources/Models/HCert.swift (Line 230)
    
    private var uvci: String? {
        
        guard let certificate = self.certificate  as? DCCCert else { return nil }
        
        return certificate.vaccinations?.first?.certificateIdentifier ??
        certificate.pastInfections?.first?.certificateIdentifier ??
        certificate.tests?.first?.certificateIdentifier
    }
    
    public var uvciHash: Data? {
        if let uvci = uvci, !uvci.isEmpty, let issuer = issuer, let countryCodeUvciData = (issuer + uvci).data(using: .utf8) {
            return Sha256.sha256(data: countryCodeUvciData) // .hexString
        } else {
            return nil
        }
    }
    
    public var countryCodeUvciHash: Data? {
        if let uvci = uvci, !uvci.isEmpty, let uvciData = uvci.data(using: .utf8) {
            return Sha256.sha256(data: uvciData) //.hexString
        } else {
            return nil
        }
    }
    
    public var signatureHash: Data? {
        var signatureBytesToHash = self.cose.signature
        
        if self.cose.protectedHeader.algorithm == .es256 {
            signatureBytesToHash = Data(Array(signatureBytesToHash.prefix(32)))
        }
        
        return Sha256.sha256(data: signatureBytesToHash) //.hexString
        
    }
}
