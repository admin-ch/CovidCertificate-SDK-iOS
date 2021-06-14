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

public enum CertLogicCommonError: String, Error {
    case RULE_PARSING_FAILED
}

public enum CertLogicValidationError: Error {
    case JSON_ERROR
    case TESTS_FAILED(tests: [String: String])
    case TEST_COULD_NOT_BE_PERFORMED(test: String)
}

public class CertLogic {
    private static let acceptanceCriteriaKey: String = "acceptance-criteria"
    private static let vaccineImmunityKey: String = "vaccine-immunity"
    private static let singleVaccineValidityOffsetKey: String = "single-vaccine-validity-offset"
    private static let pcrTestValidityKey: String = "pcr-test-validity"
    private static let ratTestValidityKey: String = "ratTestValidity"

    var rules: [JSON] = []
    var valueSets: JSON = []
    let calendar: Calendar

    public var maxValidity: Int64 { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.vaccineImmunityKey].int ?? 0 }
    public var daysAfterFirstShot: Int64 { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.singleVaccineValidityOffsetKey].int ?? 10000 }
    public var pcrValidity: Int64 { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.pcrTestValidityKey].int ?? 0 }
    public var ratValidity: Int64 { valueSets[CertLogic.acceptanceCriteriaKey][CertLogic.ratTestValidityKey].int ?? 0 }

    public init?() {
        guard let utc = TimeZone(identifier: "UTC") else {
            return nil
        }
        var tmpCalendar = Calendar(identifier: .gregorian)
        tmpCalendar.timeZone = utc
        calendar = tmpCalendar
    }

    public func updateData(rules: JSON, valueSets: JSON) -> Result<Void, CertLogicCommonError> {
        guard let array = rules.array else {
            return .failure(.RULE_PARSING_FAILED)
        }
        self.rules = array
        self.valueSets = valueSets
        return .success(())
    }

    public func checkRules(hcert: EuHealthCert, validationClock: Date = Date()) -> Result<Void, CertLogicValidationError> {
        var external = JSON(
            ["validationClock": ISO8601DateFormatter().string(from: validationClock),
             "validationClockAtStartOfDay": ISO8601DateFormatter().string(from: calendar.startOfDay(for: validationClock))]
        )
        external["valueSets"] = valueSets
        var failedTests: [String: String] = [:]
        guard let dgcJson = try? JSONEncoder().encode(hcert) else {
            return .failure(.JSON_ERROR)
        }
        let context = JSON(["external": external, "payload": JSON(dgcJson)])
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
