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

struct DisplayRulesResult {
    let validFrom: Date?
    let validUntil: Date?
    let isSwitzerlandOnly: Bool?
    let eolBannerIdentifier: String?
}

class CertLogic {
    var rules: [JSON] = []
    var valueSets: JSON = []
    var displayRules: [JSON] = []
    var modeRule: JSON?
    let calendar: Calendar
    let formatter = ISO8601DateFormatter()

    init?() {
        guard let utc = TimeZone(identifier: "UTC") else {
            return nil
        }
        var tmpCalendar = Calendar(identifier: .gregorian)
        tmpCalendar.timeZone = utc
        calendar = tmpCalendar
    }

    func updateData(rules: JSON, valueSets: JSON, displayRules: JSON, modeRule: JSON?) -> Result<Void, CertLogicCommonError> {
        guard let rulesArray = rules.array,
              let displayRulesArray = displayRules.array else {
            return .failure(.RULE_PARSING_FAILED)
        }
        self.rules = rulesArray
        self.valueSets = valueSets
        self.displayRules = displayRulesArray
        self.modeRule = modeRule
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

    func checkDisplayRules(holder: CertificateHolderType, validationClock: Date = Date()) -> Result<DisplayRulesResult, CertLogicValidationError> {
        let external = externalJson(validationClock: validationClock)

        guard let payload = createPayload(from: holder),
              let json = try? JSONEncoder().encode(payload) else {
            return .failure(.JSON_ERROR)
        }

        let context = JSON(["external": external, "payload": JSON(json)])

        var startDate: Date?
        var endDate: Date?
        var isSwitzerlandOnly: Bool?
        var eolIdentifier: String?

        for displayRule in displayRules {
            switch displayRule["id"] {
            case "display-from-date":
                // get from date
                if let result: Date = try? applyRule(displayRule["logic"], to: context) {
                    startDate = result
                }

            case "display-until-date":
                // get end date
                if let result: Date = try? applyRule(displayRule["logic"], to: context) {
                    endDate = result
                }

            case "is-only-valid-in-ch":
                // get isSwitzerland
                if let result: Bool = try? applyRule(displayRule["logic"], to: context) {
                    isSwitzerlandOnly = result
                }
            case "eol-banner":
                if let result: String = try? applyRule(displayRule["logic"], to: context) {
                    eolIdentifier = result
                }

            default:
                break
            }
        }

        return .success(DisplayRulesResult(validFrom: startDate,
                                           validUntil: endDate,
                                           isSwitzerlandOnly: isSwitzerlandOnly,
                                           eolBannerIdentifier: eolIdentifier))
    }

    func checkModeRules(holder: CertificateHolderType, modes: [CheckMode], validationClock: Date = Date()) -> [CheckMode: Result<ModeCheckResult, CertLogicValidationError>] {
        var results: [CheckMode: Result<ModeCheckResult, CertLogicValidationError>] = [:]
        let external = externalJson(validationClock: validationClock)

        for mode in modes {
            guard let modeRule = modeRule else {
                results[mode] = .failure(.TEST_COULD_NOT_BE_PERFORMED(test: "MODE_CHECK_\(mode.id)"))
                continue
            }

            guard let payload = createPayload(from: holder, mode: mode.id),
                  let json = try? JSONEncoder().encode(payload) else {
                results[mode] = .failure(.JSON_ERROR)
                continue
            }

            let context = JSON(["external": external, "payload": JSON(json)])
            if let validationCode: String = try? applyRule(modeRule, to: context) {
                results[mode] = .success(ModeCheckResult(validationCode: validationCode))
            } else {
                results[mode] = .failure(.TEST_COULD_NOT_BE_PERFORMED(test: "MODE_CHECK_\(mode.id)"))
            }
        }
        return results
    }

    private func createPayload(from holder: CertificateHolderType, mode: String? = nil) -> CertLogicPayload? {
        var issuedAt: String?
        if let iat = holder.issuedAt {
            issuedAt = DateFormatter.dayDateFormatter.string(from: iat)
        }

        var expires: String?
        if let exp = holder.expiresAt {
            expires = DateFormatter.dayDateFormatter.string(from: exp)
        }

        switch holder.certificate {
        case let certificate as DCCCert:
            return CertLogicPayload(nam: certificate.person,
                                    dob: certificate.dateOfBirth,
                                    ver: certificate.version,
                                    v: certificate.vaccinations,
                                    t: certificate.tests,
                                    r: certificate.pastInfections,
                                    h: CertLogicPayloadHeader(iat: issuedAt, exp: expires, isLight: false, mode: mode))
        case is LightCert:
            return CertLogicPayload(nam: nil,
                                    dob: nil,
                                    ver: nil,
                                    v: nil,
                                    t: nil,
                                    r: nil,
                                    h: CertLogicPayloadHeader(iat: issuedAt, exp: expires, isLight: true, mode: mode))
        default:
            assertionFailure("Unexpected Certificate type")
            return nil
        }
    }

    private func externalJson(validationClock: Date) -> JSON {
        var external = JSON(
            ["validationClock": formatter.string(from: validationClock),
             "validationClockAtStartOfDay": formatter.string(from: calendar.startOfDay(for: validationClock))])
        external["valueSets"] = valueSets
        return external
    }
}
