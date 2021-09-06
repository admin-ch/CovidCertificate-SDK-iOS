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

class Validity {
    let from: Date
    let until: Date

    init(from: Date, until: Date) {
        self.from = from
        self.until = until
    }
}

class CertLogic {
    var rules: [JSON] = []
    var valueSets: JSON = []
    var displayRules: [JSON] = []
    let calendar: Calendar

    init?() {
        guard let utc = TimeZone(identifier: "UTC") else {
            return nil
        }
        var tmpCalendar = Calendar(identifier: .gregorian)
        tmpCalendar.timeZone = utc
        calendar = tmpCalendar
    }

    func updateData(rules: JSON, valueSets: JSON, displayRules: JSON) -> Result<Void, CertLogicCommonError> {
        guard let rulesArray = rules.array,
              let displayRulesArray = displayRules.array else {
            return .failure(.RULE_PARSING_FAILED)
        }
        self.rules = rulesArray
        self.valueSets = valueSets
        self.displayRules = displayRulesArray
        return .success(())
    }

    func checkRules(hcert: DCCCert, validationClock: Date = Date()) -> Result<Void, CertLogicValidationError> {
        let external = externalJson(validationClock: validationClock)

        var failedTests: [String: String] = [:]
        guard let dccJson = try? JSONEncoder().encode(hcert) else {
            return .failure(.JSON_ERROR)
        }

        let context = JSON(["external": external, "payload": JSON(dccJson)])
        for rule in rules {
            let logic = rule["logic"]
            guard let result: Bool = try? applyRule(logic, to: context) else {
                return .failure(.TEST_COULD_NOT_BE_PERFORMED(test: rule["identifier"].string ?? "TEST_ID_UNKNOWN"))
            }
            if !result {
                failedTests.updateValue(rule["description"].string ?? "TEST_DESCRIPTION_UNKNOWN", forKey: rule["identifier"].string ?? "TEST_ID_UNKNOWN")
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

    func getValidity(hcert: DCCCert, validationClock: Date = Date()) -> Result<Validity, CertLogicValidationError> {
        let external = externalJson(validationClock: validationClock)

        guard let dccJson = try? JSONEncoder().encode(hcert) else {
            return .failure(.JSON_ERROR)
        }

        let context = JSON(["external": external, "payload": JSON(dccJson)])

        var startDate: Date?
        var endDate: Date?

        for displayRule in displayRules {
            // get from date
            if displayRule["id"] == "display-from-date" {
                guard let result: Date = try? applyRule(displayRule["logic"], to: context) else {
                    return .failure(.TEST_COULD_NOT_BE_PERFORMED(test: displayRule["id"].string ?? "VALIDITY_TEST"))
                }

                startDate = result
            }

            // get end date
            if displayRule["id"] == "display-until-date" {
                guard let result: Date = try? applyRule(displayRule["logic"], to: context) else {
                    return .failure(.TEST_COULD_NOT_BE_PERFORMED(test: displayRule["id"].string ?? "VALIDITY_TEST"))
                }

                endDate = result
            }
        }

        guard let s = startDate,
              let e = endDate else {
            return .failure(.TEST_COULD_NOT_BE_PERFORMED(test: "VALIDITY_TEST"))
        }

        return .success(Validity(from: s, until: e))
    }

    private func externalJson(validationClock: Date) -> JSON {
        let formatter = ISO8601DateFormatter()
        return JSON(
            ["validationClock": formatter.string(from: validationClock),
             "validationClockAtStartOfDay": formatter.string(from: calendar.startOfDay(for: validationClock)), "valueSets": valueSets]
        )
    }
}
