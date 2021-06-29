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

class AcceptedProducts {
    static var shared = AcceptedProducts()

    private let acceptedTests: AcceptedTests
    private let acceptedVaccines: AcceptedVaccines

    // MARK: - Vaccination API

    func vaccineIsAccepted(vaccination: Vaccination) -> Bool {
        return acceptedVaccines.entries.contains { $0.code == vaccination.medicinialProduct }
    }

    func totalNumberOfDoses(vaccination: Vaccination) -> UInt64? {
        let entry = acceptedVaccines.entries.first { $0.code == vaccination.medicinialProduct }
        return entry?.totalDosisNumber
    }

    // MARK: - Test API

    func testIsAccepted(test: Test) -> Bool {
        if test.type == TestType.Pcr.rawValue {
            return true
        }
        return acceptedTests.entries.contains {
            return test.ratTestNameAndManufacturer == $0.key
        }
    }

    // MARK: - Init

    init() {
        let acceptedTestsJson = try! String(contentsOf: Bundle.module.url(forResource: "test-manf", withExtension: "json")!)
        acceptedTests = try! JSONDecoder().decode(AcceptedTests.self, from: acceptedTestsJson.data(using: .utf8)!)
        let acceptedVaccinesJson = try! String(contentsOf: Bundle.module.url(forResource: "accepted-vaccines", withExtension: "json")!)
        acceptedVaccines = try! JSONDecoder().decode(AcceptedVaccines.self, from: acceptedVaccinesJson.data(using: .utf8)!)
    }
}
