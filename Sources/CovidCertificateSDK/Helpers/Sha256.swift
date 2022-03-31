//
//  Sh1256.swift
//  
//
//  Created by Dennis Jüni on 16.03.22.
//

import Foundation
import CommonCrypto

class Sha256 {
    public static func digest(input: NSData) -> Data {
      if #available(iOS 13.0, *) {
        return iOS13Digest(input: input)
      }
      return iOS12Digest(input: input)
    }

    public static func sha256(data : Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
  public static func iOS12Digest(input: NSData) -> Data {
    let input = input as Data
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    _ = input.withUnsafeBytes { bytes in
      CC_SHA256(bytes.baseAddress, CC_LONG(input.count), &digest)
    }
    return Data(digest)
  }

  public static func iOS13Digest(input: NSData) -> Data {
    let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
    var hash = [UInt8](repeating: 0, count: digestLength)
    CC_SHA256(input.bytes, UInt32(input.length), &hash)
    return Data(NSData(bytes: hash, length: digestLength))
  }

  public static func stringDigest(input: Data) -> String {
    return digest(input: input as NSData).base64EncodedString()
  }

  private func hexString(_ iterator: Array<UInt8>.Iterator) -> String {
    return iterator.map { String(format: "%02x", $0) }.joined()
  }
}
