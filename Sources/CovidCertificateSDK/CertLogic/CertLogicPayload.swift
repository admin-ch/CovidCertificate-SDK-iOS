//
//  CertLogicPayload.swift
//  
//
//  Created by Matthias Felix on 17.11.21.
//

import Foundation

struct CertLogicPayload: Codable {
    let v: [Vaccination]?
    let t: [Test]?
    let r: [PastInfection]?
    let h: CertLogicPayloadHeader?
}

struct CertLogicPayloadHeader: Codable {
    let iat: String?
    let exp: String?
}
