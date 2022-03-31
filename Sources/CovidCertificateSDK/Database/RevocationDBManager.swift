//
//  File.swift
//  
//
//  Created by Dennis Jüni on 16.03.22.
//

import Foundation
import SQLite


class RevocationDBManager {
    
    static var pathToDatabase: String {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return "\(path)/revocations.sqlite3"
    }
    
    private let db: Connection
    
    //This table is for the Wallet (Here nothing for Bloomfilters is stored)
    private var hashTable: Table!
    private let hashTableName = "Hash"
    
    init() {
        db = try! Connection(RevocationDBManager.pathToDatabase, readonly: false)
        
        hashTable = try! initializeHashTable()
    }
    
    private let id = Expression<Int64>("id")
    private let hashType = Expression<String>("hashType")
    private let hash = Expression<String>("hash")
    private let expires = Expression<Int64>("expires")
    private let inserted = Expression<Int64>("inserted")

    
    private func initializeHashTable() throws -> Table {
        let hashTable = Table(hashTableName)
        try db.run(hashTable.create(ifNotExists: true) { (t) in
            t.column(id, primaryKey: PrimaryKey.autoincrement)
            t.column(hashType)
            t.column(hash)
            t.column(expires)
            t.column(inserted)
        })
        return hashTable
    }
    
    public func checkSingleCert(_ holder: CertificateHolder) -> (Int64, Int64, Bool) {
        
        //TODO: Check if hash matches for any of the 3 possibilities
        // -> IF one hash is in DB we return the expires and inserted dates s.t. 
        let possibleArrays = [holder.countryCodeUvciHash, holder.uvciHash, holder.signatureHash]
        
        hashTable.filter( possibleArrays.contains(hash) ).limit(1)
        
        return (0,0)
    }
    
    
    public func validataeRevocation(holder: CertificateHolder) {
        
        // TODO
        // 1. check if prefix is in DB and not expired -> return valid
        // 2. if prefix in bloomfilter && expired or if prefix in bloomfilter && hit for specific hash
        //    -> Request this specific Cert with country, key-id, prefix -> check if cert is in returned list (If no internet, show popup)
        
        //TODO: DE add 3rd one
        
//        let certificate = holder.certificate
//        
//        //Only ever exactly one of them is found (if there is one)
//        let uvci: String = certificate.vaccinations?.first?.certificateIdentifier ??
//            certificate.pastInfections?.first?.certificateIdentifier ??
//            certificate.tests?.first?.certificateIdentifier ?? ""
        
        
        //3 Hashes: Signature, UVCI, CC+UVCI
//        let hashedData = [holder.cose.signature, holder.cwt.].map { RevocationDBManager.sha256.digest(data: [UInt8]($0)) }
        
//        let prefixes = hashedData.map { String(Data($0).base64EncodedString().prefix(2)) }
//        
//        prefixes.forEach {
//            let query = hashTable.select(expires).filter(prefix == $0)
//        }
    }
}
