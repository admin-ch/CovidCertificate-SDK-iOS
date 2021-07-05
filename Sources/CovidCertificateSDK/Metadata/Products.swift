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
