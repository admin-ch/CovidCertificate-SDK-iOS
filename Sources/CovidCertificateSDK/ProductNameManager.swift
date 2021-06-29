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

    private let vaccineManufacturers = ProductNameManager.loadProductNames(file: "vaccine-mah-manf")
    private let vaccineProducts = ProductNameManager.loadProductNames(file: "vaccine-medicinal-product")
    private let vaccineProphylaxis = ProductNameManager.loadProductNames(file: "vaccine-prophylaxis")
    private let testManufacturers = ProductNameManager.loadProductNames(file: "test-manf")
    private let testTypes = ProductNameManager.loadProductNames(file: "test-type")
    private let testResults = ProductNameManager.loadProductNames(file: "test-result")

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

    func testResultName(key: String?) -> String? {
        return testResults.productName(key: key)
    }

    // MARK: - Loading helper

    static func loadProductNames(file: String) -> Products {
        guard let url = Bundle.module.url(forResource: file, withExtension: "json"),
              let json = try? String(contentsOf: url),
              let data = json.data(using: .utf8),
              let products = try? JSONDecoder().decode(Products.self, from: data)
        else {
            return Products()
        }

        return products
    }
}

class ProductEntry: Codable {
    let display: String?
    let lang: String?
    let active: Bool?
    let system: String?
    let version: String?
}

class Products: Codable {
    let valueSetId: String?
    let valueSetDate: String?
    let valueSetValues: [String: ProductEntry]

    init() {
        valueSetId = nil
        valueSetDate = nil
        valueSetValues = [:]
    }

    // MARK: - Product name helper

    func productName(key: String?) -> String? {
        guard let k = key,
              let p = valueSetValues[k],
              let name = p.display
        else {
            let empty = key?.isEmpty ?? true
            return empty ? nil : key
        }

        return name
    }
}
