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

class ProductNameManager {
    // MARK: - Lookup Tables

    private var vaccineManufacturers: Products { MetadataManager.currentMetadata.vaccine.mahManf }
    private var vaccineProducts: Products { MetadataManager.currentMetadata.vaccine.medicinalProduct }
    private var vaccineProphylaxis: Products { MetadataManager.currentMetadata.vaccine.prophylaxis }
    private var testManufacturers: Products { MetadataManager.currentMetadata.test.manf }
    private var testTypes: Products { MetadataManager.currentMetadata.test.type }

    // MARK: - Shared instance

    static let shared = ProductNameManager()

    // MARK: - API

    func vaccineManufacturer(key: String?) -> String? {
        return vaccineManufacturers.productName(key: key)
    }

    func vaccineProductName(key: String?) -> String? {
        return vaccineProducts.productName(key: key)
    }

    func vaccineProphylaxisName(key: String?) -> String? {
        return vaccineProphylaxis.productName(key: key)
    }

    func testManufacturerName(key: String?) -> String? {
        return testManufacturers.productName(key: key)
    }

    func testTypeName(key: String?) -> String? {
        return testTypes.productName(key: key)
    }
}
