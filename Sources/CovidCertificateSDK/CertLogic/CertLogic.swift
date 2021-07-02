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
    private static let acceptanceCriteriaKey: String = "acceptance-criteria"
    private static let vaccineImmunityKey: String = "vaccine-immunity"
    private static let singleVaccineValidityOffsetKey: String = "single-vaccine-validity-offset"
    private static let pcrTestValidityKey: String = "pcr-test-validity"
    private static let ratTestValidityKey: String = "rat-test-validity"
    private static let recoveryOffsetValidFrom: String = "recovery-offset-valid-from"
    private static let recoveryOffsetValidUntil: String = "recovery-offset-valid-until"

    var rules: [JSON] = []
    var valueSets: JSON = []
    let calendar: Calendar

    var maxValidity: Int64? { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.vaccineImmunityKey].int }
    var daysAfterFirstShot: Int64? { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.singleVaccineValidityOffsetKey].int }
    var pcrValidity: Int64? { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.pcrTestValidityKey].int }
    var ratValidity: Int64? { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.ratTestValidityKey].int }

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
}
