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
    private let hashTableName = "Hash_Table"
    
    private var prefixTable: Table!
    private let prefixTableName = "Prefix_Table"
    
    init() {
        db = try! Connection(RevocationDBManager.pathToDatabase, readonly: false)
        
        hashTable = try! initializeHashTable()
        prefixTable = try! initializePrefixTable()
    }
    
    private let hashId = Expression<Int64>("hashId")
    private let hashType = Expression<String?>("hashType")
    private let hash = Expression<String>("hash")
    private let hashExpires = Expression<Int64>("hashExpires")
    private let hashInserted = Expression<Int64>("hashInserted")
    private let hashNextSince = Expression<String?>("hashNextSince")

    
    private func initializeHashTable() throws -> Table {
        let hashTable = Table(hashTableName)
        try db.run(hashTable.create(ifNotExists: true) { (t) in
            t.column(hashId, primaryKey: PrimaryKey.autoincrement)
            t.column(hashType)
            t.column(hash)
            t.column(hashExpires)
            t.column(hashInserted)
            t.column(hashNextSince)
        })
        return hashTable
    }
    
    private let prefixId = Expression<Int64>("prefixId")
    private let prefix = Expression<String>("prefix")
    private let prefixExpires = Expression<Int64>("prefixExpires")
    private let prefixInserted = Expression<Int64>("prefixInserted")
    private let prefixNextSince = Expression<String?>("prefixNextSince")
    
    
    private func initializePrefixTable() throws -> Table {
        let prefixTable = Table(prefixTableName)
        try db.run(prefixTable.create(ifNotExists: true) { (t) in
            t.column(hashId, primaryKey: PrimaryKey.autoincrement)
            t.column(prefix)
            t.column(prefixExpires)
            t.column(prefixInserted)
            t.column(prefixNextSince)
        })
        return prefixTable
    }
    
    
    public func insert(_ hashes: RevocationHashes, _ nextSinceHash: String?) -> Bool {
        do {
            guard let hashFilters = hashes.hashFilters else { return false }
            let now = Int64(Date().timeIntervalSince1970 * 1000.0)
            for hashFilter in hashFilters {
                try db.run(hashTable.insert(hashType <- hashFilter.hashType, hash <- hashFilter.hash, hashExpires <- hashes.expires, hashInserted <- now, hashNextSince <- nextSinceHash))
            }
            return true
        } catch {
            print("insertion failed: \(error)")
            return false
        }
    }
    
    public func getAll() -> RevocationHashesStorage? {
        do {
            let all = Array(try db.prepare(hashTable))
            
            let result = RevocationHashesStorage()
            try result.hashedRevocationList = all.map { HashFilter(hash: try $0.get(hash), hashType: try $0.get(hashType)) }
            try result.lastDownload = all.first?.get(hashInserted) ?? 0
            try result.expires = all.first?.get(hashExpires) ?? 0
            return result
        } catch {
            return nil
        }
    }
    
    //First to return arguments are expires and inserted (needed to check if the current dates are still valid), 3rd argument is flag for isInDB
    public func checkSingleCert(_ holder: CertificateHolder) -> (Int64?, Int64?) {
        
        //TODO: DE, check if the prefix is in DB and return its Expiration and Insertion date!
        
        let possibleArrays = [holder.countryCodeUvciHash, holder.uvciHash, holder.signatureHash].compactMap {
            $0?.base64EncodedString().substring(toIndex:6)
        }

        let results = hashTable.where(possibleArrays.contains(hash)).limit(1)
        
        //If there is an entry in the DB for one of the hashes, we return its expirationDate and insertionDate, otherwise we just return nil to state that the hash is not in the DB
        if let first = try? db.pluck(results) {
            return (try? first.get(hashExpires), try? first.get(hashInserted))
        }
        return (nil, nil)
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
