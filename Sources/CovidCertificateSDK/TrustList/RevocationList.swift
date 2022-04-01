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

public class RevocationList: Codable, JWTExtension {
    public var revokedCerts: Set<String> = []
    public var validDuration: Int64 = 0
}


public class RevocationHashes: Codable, JWTExtension {
    public var bloomFilters: [BloomFilter]? = []
    public var hashFilters: [HashFilter]? = []
    public var expires: Int64 = 0
    public var etag: String = ""
}


public class BloomFilter: Codable, JWTExtension {
    
}

public class HashFilter: Codable, JWTExtension {
    public var hash: String = ""
    public var hashType: String? = nil
    
    init(hash: String, hashType: String?) {
        self.hash = hash
        self.hashType = hashType
    }
}
