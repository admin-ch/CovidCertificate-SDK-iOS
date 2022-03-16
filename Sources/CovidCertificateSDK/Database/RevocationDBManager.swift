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
    
    static let sha256 = Sha256()
    
    private let db: Connection
    
    private var filterTable: Table!
    private let filterTableName = "Filter"
    
    private var hashTable: Table!
    private let hashTableName = "Hash"
    
    init() {
        db = try! Connection(RevocationDBManager.pathToDatabase, readonly: false)
        
//        filterTable = try! initializeFilterTable()
        hashTable = try! initializeHashTable()
    }
    
    private let id = Expression<Int64>("id")
    private let kid = Expression<String>("kid")
    private let prefix = Expression<String>("prefix")
    private let hashType = Expression<String>("hashType")
    private let hash = Expression<String>("hash")
    private let expires = Expression<Int64>("expires")

    
    private func initializeFilterTable() throws -> Table {
        let filterTable = Table(filterTableName)
        try db.run(filterTable.create(ifNotExists: true) { (t) in
        })
        return filterTable
    }
    
    private func initializeHashTable() throws -> Table {
        let hashTable = Table(hashTableName)
        try db.run(hashTable.create(ifNotExists: true) { (t) in
            t.column(id, primaryKey: PrimaryKey.autoincrement)
            t.column(kid)
            t.column(prefix)
            t.column(hashType)
            t.column(hash)
            t.column(expires)
        })
        return hashTable
    }
    
    
    public func checkCertExistsAndValid(holder: CertificateHolder) {
        
        //TODO: DE add 3rd one
        
        //3 Hashes: Signature, UVCI, CC+UVCI
        let hashedData = [holder.cose.signature, holder.cwt.].map { RevocationDBManager.sha256.digest(data: [UInt8]($0)) }
        
        let prefixes = hashedData.map { String(Data($0).base64EncodedString().prefix(2)) }
        
        prefixes.forEach {
            let query = hashTable.select(expires).filter(prefix == $0)
        }
    }
}
