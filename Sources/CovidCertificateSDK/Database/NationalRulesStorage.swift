//
/*
 * Copyright (c) 2021 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation
import SQLite

class NationalRulesListEntry {
    var nationalRulesList: NationalRulesList
    var lastDownloaded: Int64
    
    var isValid: Bool {
        return isStillValid(downloadTimeStamp: lastDownloaded, validDuration: nationalRulesList.validDuration)
    }
    
    internal init(nationalRulesList: NationalRulesList, lastDownloaded: Int64) {
        self.nationalRulesList = nationalRulesList
        self.lastDownloaded = lastDownloaded
    }
    
    // MARK: - Validity
    
    private func isStillValid(downloadTimeStamp: Int64, validDuration: Int64) -> Bool {
        let stillValidUntil = downloadTimeStamp + validDuration
        let validUntilDate = Date(timeIntervalSince1970: Double(stillValidUntil) / 1000.0)
        return Date().isBefore(validUntilDate)
    }
}

class NationalRulesStorage {
    
    static let shared = NationalRulesStorage()
    
    /// Database connection
    private let database: Connection
    
    private let queue = DispatchQueue(label: "org.cert.nationallist")
    
    /// Name of the table
    let table = Table("nationalLists")
    
    /// Column definitions
    let countryCodeColumn = Expression<String>("countryCode")
    let lastDownloadColumn = Expression<Int64>("lastDownload")
    let nationalListColumn = Expression<Data?>("nationalListData")
    
    /// get database path
    private static func getDatabasePath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("national_list").appendingPathExtension("sqlite")
    }
    
    /// Initializer
    private init() {
        let filePath = NationalRulesStorage.getDatabasePath()
        database = try! Connection(filePath.absoluteString, readonly: false)
        try! createTable()
    }
    
    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(countryCodeColumn, primaryKey: true)
            t.column(lastDownloadColumn)
            t.column(nationalListColumn)
        })
    }
    
    /// Updates the entries of a nationalRulesList or inserts a new one if not existing yet.
    public func updateOrInsertNationalRulesList(list: NationalRulesList, countryCode: String) -> Bool {
        queue.sync { [weak self] in
            guard let self = self else { return false }
            let encodedList = try? JSONEncoder().encode(list)
            let insertOrReplace = self.table.insert(
                or: .replace,
                self.countryCodeColumn <- countryCode,
                self.lastDownloadColumn <- Int64(Date().timeIntervalSince1970 * 1000.0),
                self.nationalListColumn <- encodedList
            )
            do {
                _ = try self.database.run(insertOrReplace)
                return true
            } catch {
                return false
            }
        }
    }
    
    public func getNationalRulesListEntry(countryCode: String) -> NationalRulesListEntry? {
        queue.sync {
            let query = table.filter(countryCodeColumn == countryCode).limit(1).select(nationalListColumn, lastDownloadColumn)
            
            if let row = try? database.pluck(query) {
                guard let data = row[nationalListColumn],
                      let nationalList = try? JSONDecoder().decode(NationalRulesList.self, from: data) else { return nil }
                return NationalRulesListEntry(nationalRulesList: nationalList, lastDownloaded: row[lastDownloadColumn])
            }
            
            return nil
        }
    }
    
    
}
