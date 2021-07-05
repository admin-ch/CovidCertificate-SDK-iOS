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

class MetadataReponse: UBCodable, JWTExtension {
    let test: TestResponse
    let vaccine: VaccineResponse
}

class TestResponse: Codable {
    let type: Products
    let manf: Products
}

class VaccineResponse: Codable {
    let mahManf: Products
    let medicinalProduct: Products
    let prophylaxis: Products
}
