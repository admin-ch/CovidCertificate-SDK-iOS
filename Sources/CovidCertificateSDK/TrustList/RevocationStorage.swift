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

class RevocationStorage {

    private var databasePath = getDatabasePath()

    private let database: Connection

    private let revocationsTable = Table("revocations")
    private let uvciColumn = Expression<String>("uvci")

    private let metadataTable = Table("metadata")
    private let validDurationColumn = Expression<Int64>("validDuration")
    private let lastDownloadColumn = Expression<Int64>("lastDownload")
    private let nextSinceColumn = Expression<String?>("nextSince")

    init() {
        // replace database if a newer database file is bundled with the app
        if let bundleRevocations = Bundle.module.url(forResource: "revocations", withExtension: "sqlite"),
           CovidCertificateSDK.currentEnvironment == .prod,
           (bundleRevocations.lastModified ?? .distantFuture) > (databasePath.lastModified ?? .distantPast)
        {
            // first delete existing file if it exists
            if (FileManager.default.fileExists(atPath: databasePath.path)) {
                try! FileManager.default.removeItem(at: databasePath)
            }
            // then copy the bundled file
            try! FileManager.default.copyItem(at: bundleRevocations, to: databasePath)
        }

        database = try! Connection(databasePath.absoluteString, readonly: false)

        createTableIfNeeded()
    }

    private func createTableIfNeeded() {
        // fallback if no database was bundled we create the schema
        // this is only used for non production enviroments
        _ = try? database.run(revocationsTable.create(ifNotExists: true) { t in
            t.column(uvciColumn)
        })

        _ = try? database.run(metadataTable.create(ifNotExists: true) { t in
            t.column(validDurationColumn)
            t.column(lastDownloadColumn)
            t.column(nextSinceColumn)
        })

        if ((try? database.scalar(metadataTable.count)) ?? 0 == 0) {
            _ = try? database.run(metadataTable.insert(validDurationColumn <- 0, lastDownloadColumn <- 0))
        }

        _ = try? database.run(revocationsTable.createIndex(uvciColumn, unique: true, ifNotExists: true))
    }

    var lastDownload: Int64 {
        get {
            return getMetadataColumn(lastDownloadColumn, defaultValue: 0)
        }
        set {
            _ = try? database.run(metadataTable.update(lastDownloadColumn <- newValue))
        }
    }
    var validDuration: Int64 {
        get {
            return getMetadataColumn(validDurationColumn, defaultValue: 0)
        }
        set {
            _ = try? database.run(metadataTable.update(validDurationColumn <- newValue))
        }
    }
    var nextSince: String? {
        get {
            return getMetadataColumn(nextSinceColumn, defaultValue: nil)
        }
        set {
            _ = try? database.run(metadataTable.update(nextSinceColumn <- newValue))
        }
    }

    private func getMetadataColumn<Datatype: Value>(_ column: Expression<Datatype>, defaultValue: Datatype) -> Datatype {
        do {
            return try database.pluck(metadataTable)?.get(column) ?? defaultValue
        } catch {}
        return defaultValue
    }

    private func getMetadataColumn<Datatype: Value>(_ column: Expression<Datatype?>, defaultValue: Datatype?) -> Datatype? {
        do {
            return try database.pluck(metadataTable)?.get(column) ?? defaultValue
        } catch {}
        return defaultValue
    }

    func updateRevocationList(_ list: RevocationList, nextSince: String) -> Bool {
        let success = list.revokedCerts.allSatisfy { uvci in
            do {
                try database.run(revocationsTable.insert(or: .replace,uvciColumn <- uvci))
                return true
            } catch {
                return false
            }
        }
        if success {
            self.validDuration = list.validDuration
            self.lastDownload = Int64(Date().timeIntervalSince1970 * 1000.0)
            self.nextSince = nextSince
        }
        return success
    }
    
    func isCertificateRevoced(uvci: String) -> Bool {
        do {
            return try database.scalar(revocationsTable.filter(uvciColumn == uvci).exists)
        } catch {
            return false
        }
    }

    private static func getDatabasePath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("revocations").appendingPathExtension("sqlite")
    }
}


fileprivate extension URL {
    var lastModified: Date? {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: path)
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }
}
