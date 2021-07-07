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
import JSON
import jsonlogic

enum CertLogicCommonError: String, Error {
    case RULE_PARSING_FAILED
}

enum CertLogicValidationError: Error {
    case JSON_ERROR
    case TESTS_FAILED(tests: [String: String])
    case TEST_COULD_NOT_BE_PERFORMED(test: String)
}

class CertLogic {
    enum JsonLogicKeys: String {
        case oneDoseVaccine = "one-dose-vaccines-with-offset"
        case twoDoseVaccine = "two-dose-vaccines"
        case acceptanceCriteria = "acceptance-criteria"
    }

    enum AcceptanceCriteriaKeys: String {
        case vaccineImmunityKey = "vaccine-immunity"
        case singleVaccineValidityOffsetKey = "single-vaccine-validity-offset"
        case twoVaccineValidityOffsetKey = "two-doses-vaccine-validity-offset"
        case pcrTestValidityKey = "pcr-test-validity"
        case ratTestValidityKey = "rat-test-validity"
        case recoveryOffsetValidFrom = "recovery-offset-valid-from"
        case recoveryOffsetValidUntil = "recovery-offset-valid-until"
    }

    var rules: [JSON] = []
    var valueSets: JSON = []
    let calendar: Calendar

    var maxRecoveryValidity: Int64? { valueSets[JsonLogicKeys.acceptanceCriteria.rawValue][AcceptanceCriteriaKeys.recoveryOffsetValidUntil.rawValue].int }
    var maxValidity: Int64? { valueSets[JsonLogicKeys.acceptanceCriteria.rawValue][AcceptanceCriteriaKeys.vaccineImmunityKey.rawValue].int }
    var pcrValidity: Int64? { valueSets[JsonLogicKeys.acceptanceCriteria.rawValue][AcceptanceCriteriaKeys.pcrTestValidityKey.rawValue].int }
    var ratValidity: Int64? { valueSets[JsonLogicKeys.acceptanceCriteria.rawValue][AcceptanceCriteriaKeys.ratTestValidityKey.rawValue].int }
    var singleVaccineValidityOffset: Int64? { valueSets[JsonLogicKeys.acceptanceCriteria.rawValue][AcceptanceCriteriaKeys.singleVaccineValidityOffsetKey.rawValue].int }
    var twoVaccineValidityOffset: Int64? { valueSets[JsonLogicKeys.acceptanceCriteria.rawValue][AcceptanceCriteriaKeys.twoVaccineValidityOffsetKey.rawValue].int }

    var oneDoseVaccines: [String] { valueSets[JsonLogicKeys.oneDoseVaccine.rawValue].array?.compactMap { $0.string } ?? [] }
    var twoDoseVaccines: [String] { valueSets[JsonLogicKeys.twoDoseVaccine.rawValue].array?.compactMap { $0.string } ?? [] }

    init?() {
        guard let utc = TimeZone(identifier: "UTC") else {
            return nil
        }
        var tmpCalendar = Calendar(identifier: .gregorian)
        tmpCalendar.timeZone = utc
        calendar = tmpCalendar
    }

    func updateData(rules: JSON, valueSets: JSON) -> Result<Void, CertLogicCommonError> {
        guard let array = rules.array else {
            return .failure(.RULE_PARSING_FAILED)
        }
        self.rules = array
        self.valueSets = valueSets
        return .success(())
    }

    func checkRules(hcert: DCCCert, validationClock: Date = Date()) -> Result<Void, CertLogicValidationError> {
        var external = JSON(
            ["validationClock": ISO8601DateFormatter().string(from: validationClock),
             "validationClockAtStartOfDay": ISO8601DateFormatter().string(from: calendar.startOfDay(for: validationClock))]
        )
        external["valueSets"] = valueSets
        var failedTests: [String: String] = [:]
        guard let dccJson = try? JSONEncoder().encode(hcert) else {
            return .failure(.JSON_ERROR)
        }
        let context = JSON(["external": external, "payload": JSON(dccJson)])
        for rule in rules {
            let logic = rule["logic"]
            guard let result: Bool = try? applyRule(logic, to: context) else {
                return .failure(.TEST_COULD_NOT_BE_PERFORMED(test: rule["id"].string ?? "TEST_ID_UNKNOWN"))
            }
            if !result {
                failedTests.updateValue(rule["description"].string ?? "TEST_DESCRIPTION_UNKNOWN", forKey: rule["id"].string ?? "TEST_ID_UNKNOWN")
                // for now we break at the first occurence of an error
                break
            }
        }
        if failedTests.isEmpty {
            return .success(())
        } else {
            return .failure(.TESTS_FAILED(tests: failedTests))
        }
    }

    private func getTotalDoses(for vaccination: String?) -> Int? {
        guard let vaccination = vaccination else { return 2 }
        if oneDoseVaccines.contains(vaccination) {
            return 1
        } else if twoDoseVaccines.contains(vaccination) {
            return 2
        }
        return nil
    }

    func getValidityRange(vaccination: Vaccination?) -> (from: Date, until: Date)? {
        guard let vaccination = vaccination,
              let maxValidity = maxValidity,
              let singleVaccineValidityOffset = singleVaccineValidityOffset,
              let twoVaccineValidityOffset = twoVaccineValidityOffset,
              let totalDoses = getTotalDoses(for: vaccination.medicinialProduct) else { return nil }

        guard let validUntil = vaccination.getValidUntilDate(maximumValidityInDays: Int(maxValidity)) else { return nil }

        guard let validFrom = vaccination.getValidFromDate(singleVaccineValidityOffset: Int(singleVaccineValidityOffset),
                                                           twoVaccineValidityOffset: Int(twoVaccineValidityOffset),
                                                           totalDoses: totalDoses) else { return nil }

        return (from: validFrom, until: validUntil)
    }
}
