//
//  Sh1256.swift
//  
//
//  Created by Dennis Jüni on 16.03.22.
//

import Foundation
import CommonCrypto

class Sha256 {
    private var context = CC_SHA256_CTX()
    private var hash: [UInt8]
    public init() {
        self.hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Init(&context)
    }
    
    public func update(_ data: [UInt8]) {
        let _ = data.withUnsafeBytes { dataPtr in
            CC_SHA256_Update(&context, dataPtr.baseAddress!, CC_LONG(data.count))
        }
    }
    public func digest(data: [UInt8]) -> [UInt8] {
        let _ = data.withUnsafeBytes { dataPtr in
            CC_SHA256(dataPtr.baseAddress!, CC_LONG(data.count), &hash)
        }
        return hash
    }
    public func digest() -> [UInt8] {
        CC_SHA256_Final(&hash, &context)
        CC_SHA256_Init(&context)
        return hash
    }
}
