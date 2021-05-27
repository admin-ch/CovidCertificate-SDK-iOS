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

let PCR_TEST_VALIDITY_IN_HOURS = 72
let RAT_TEST_VALIDITY_IN_HOURS = 24
let SINGLE_VACCINE_VALIDITY_OFFSET_IN_DAYS = 15
let DATE_FORMAT = "yyyy-MM-dd"

public enum NationalRulesError: Error, Equatable {
    case NO_VALID_PRODUCT
    case WRONG_DISEASE_TARGET
    case WRONG_TEST_TYPE
    case POSITIVE_RESULT
    case NOT_FULLY_PROTECTED
    case NO_VALID_DATE

    public var errorCode: String {
        switch self {
        case .NO_VALID_PRODUCT: return "N|NVP"
        case .WRONG_DISEASE_TARGET: return "N|WDT"
        case .WRONG_TEST_TYPE: return "N|WTT"
        case .POSITIVE_RESULT: return "N|PR"
        case .NOT_FULLY_PROTECTED: return "N|NFP"
        case .NO_VALID_DATE: return "N|NVD"
        }
    }
}

public enum NationalRulesDateError: Error, Equatable {
    case NOT_YET_VALID
    case EXPIRED
}

public struct VerificationResult {
    public let isValid: Bool
    public let validUntil: Date?
    public let validFrom: Date?
    public let dateError: NationalRulesDateError?
}

class NationalRulesVerifier {
    init() {}

    // MARK: - Test

    public func verifyTest(test: Test, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        // tg must be sars-cov2
        if !test.isTargetDiseaseCorrect {
            completionHandler(.failure(.WRONG_DISEASE_TARGET))
            return
        }

        if !test.isNegative {
            completionHandler(.failure(.POSITIVE_RESULT))
            return
        }

        // test type must be RAT or PCR
        if test.type != TestType.Rat.rawValue, test.type != TestType.Pcr.rawValue {
            completionHandler(.failure(.WRONG_TEST_TYPE))
            return
        }

        // test must be in accepted list and be accepted by either EU or CH
        guard AcceptedProducts.shared.testIsAccepted(test: test) else {
            completionHandler(.failure(.NO_VALID_PRODUCT))
            return
        }

        guard let validFromDate = test.validFromDate,
              let validUntilDate = test.validUntilDate
        else {
            completionHandler(.failure(.NO_VALID_DATE))
            return
        }

        if validFromDate.isAfter(Date()) {
            completionHandler(.success(VerificationResult(isValid: false, validUntil: test.validUntilDate, validFrom: test.validFromDate, dateError: .NOT_YET_VALID)))
            return
        }
        if validUntilDate.isBefore(Date()) {
            completionHandler(.success(VerificationResult(isValid: false, validUntil: test.validUntilDate, validFrom: test.validFromDate, dateError: .EXPIRED)))
            return
        }

        completionHandler(.success(VerificationResult(isValid: true, validUntil: test.validUntilDate, validFrom: test.validFromDate, dateError: nil)))
    }

    // MARK: - Vaccine

    public func verifyVaccine(vaccine: Vaccination, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        // tg must be sars-cov2
        if !vaccine.isTargetDiseaseCorrect {
            completionHandler(.failure(.WRONG_DISEASE_TARGET))
            return
        }

        // dosis number must be greater or equal to total number of dosis
        if vaccine.doseNumber < vaccine.totalDoses {
            completionHandler(.failure(.NOT_FULLY_PROTECTED))
            return
        }

        // check if vaccine is in accepted products list
        guard AcceptedProducts.shared.vaccineIsAccepted(vaccination: vaccine) else {
            completionHandler(.failure(.NO_VALID_PRODUCT))
            return
        }

        let today = Calendar.current.startOfDay(for: Date())

        guard let validFromDate = vaccine.validFromDate,
              let validUntilDate = vaccine.validUntilDate
        else {
            completionHandler(.failure(.NO_VALID_DATE))
            return
        }

        if validFromDate.isAfter(today) {
            completionHandler(.success(VerificationResult(isValid: false, validUntil: vaccine.validUntilDate, validFrom: vaccine.validFromDate, dateError: .NOT_YET_VALID)))
            return
        }
        if validUntilDate.isBefore(today) {
            completionHandler(.success(VerificationResult(isValid: false, validUntil: vaccine.validUntilDate, validFrom: vaccine.validFromDate, dateError: .EXPIRED)))
            return
        }

        completionHandler(.success(VerificationResult(isValid: true, validUntil: vaccine.validUntilDate, validFrom: vaccine.validFromDate, dateError: nil)))
    }

    // MARK: - Recoveery

    public func verifyRecovery(recovery: PastInfection, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void) {
        if recovery.disease != Disease.SarsCov2.rawValue {
            completionHandler(.failure(.WRONG_DISEASE_TARGET))
            return
        }

        guard let validFromDate = recovery.validFromDate,
              let validUntilDate = recovery.validUntilDate
        else {
            completionHandler(.failure(.NO_VALID_DATE))
            return
        }

        // certificate is accepted 10 days after positive testresult...
        if validFromDate.isAfter(Calendar.current.startOfDay(for: Date())) {
            completionHandler(.success(VerificationResult(isValid: false, validUntil: recovery.validUntilDate, validFrom: recovery.validFromDate, dateError: .NOT_YET_VALID)))
            return
        }
        // ... and valid until 6 months after first testresult
        else if validUntilDate.isBefore(Calendar.current.startOfDay(for: Date())) {
            completionHandler(.success(VerificationResult(isValid: false, validUntil: recovery.validUntilDate, validFrom: recovery.validFromDate, dateError: .EXPIRED)))
            return
        }

        completionHandler(.success(VerificationResult(isValid: true, validUntil: recovery.validUntilDate, validFrom: recovery.validFromDate, dateError: nil)))
    }
}

class AcceptedTests: Codable {
    var id: String
    var creationDate: String
    var entries: [String: ProductEntry]
    private enum CodingKeys: String, CodingKey {
        case id = "valueSetId"
        case creationDate = "valueSetDate"
        case entries = "valueSetValues"
    }
}

class AcceptedVaccines: Codable {
    var id: String
    var date: String
    var version: String
    var entries: [AcceptedVaccine]

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case date = "Date"
        case version = "Version"
        case entries
    }
}

class AcceptedVaccine: Codable {
    var name: String
    var code: String
    var prophylaxis: String
    var prophylaxisCode: String
    var authHolder: String
    var authHolderCode: String
    var totalDosisNumber: UInt64
    var active: Bool

    private enum CodingKeys: String, CodingKey {
        case name, code, active, prophylaxis
        case prophylaxisCode = "prophylaxis_code"
        case authHolder = "auth_holder"
        case authHolderCode = "auth_holder_code"
        case totalDosisNumber = "total_dosis_number"
    }
}

class AcceptedTest: Codable {
    var name: String
    var naaTestName: String
    var typeCode: TestType
    var manufacturer: String
    var swissTestKit: String
    var ratTestNameAndManufacturer: String
    var euAccepted: Bool
    var chAccepted: Bool
    var active: Bool

    private enum CodingKeys: String, CodingKey {
        case name, manufacturer, active
        case naaTestName = "type"
        case typeCode = "type_code"
        case swissTestKit = "swiss_test_kit"
        case ratTestNameAndManufacturer = "manufacturer_code_eu"
        case euAccepted = "eu_accepted"
        case chAccepted = "ch_accepted"
    }
}

enum Disease: String, Equatable {
    case SarsCov2 = "840539006"
}

enum TestType: String, Equatable, Codable {
    case Rat = "LP217198-3"
    case Pcr = "LP6464-4"
}

enum TestResult: String, Equatable, Codable {
    case Detected, Positive = "260373001"
    case NotDetected, Negative = "260415000"
}
