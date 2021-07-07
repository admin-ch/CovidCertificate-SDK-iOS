//
//  EuHealthCert.swift
//
//
//  Created by Dominik Mocher on 14.04.21.
//

import Foundation
import SwiftCBOR

public struct DCCCert: CovidCertificate, Codable {
    public let person: Person
    public let dateOfBirth: String
    public let version: String
    public let vaccinations: [Vaccination]?
    public let pastInfections: [PastInfection]?
    public let tests: [Test]?

    public var type: CertificateType { .dccCert }

    public var immunisationType: ImmunisationType? {
        if let v = vaccinations, v.count == 1,
           self.pastInfections.isNilOrEmpty(),
           self.tests.isNilOrEmpty() {
            return .vaccination
        } else if let p = pastInfections, p.count == 1,
                  self.tests.isNilOrEmpty(),
                  self.vaccinations.isNilOrEmpty() {
            return .recovery
        } else if let tests = self.tests, tests.count == 1,
                  self.pastInfections.isNilOrEmpty(),
                  self.vaccinations.isNilOrEmpty() {
            return .test
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case person = "nam"
        case dateOfBirth = "dob"
        case vaccinations = "v"
        case pastInfections = "r"
        case tests = "t"
        case version = "ver"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        person = try container.decode(Person.self, forKey: .person)
        version = try container.decode(String.self, forKey: .version)
        dateOfBirth = try container.decode(String.self, forKey: .dateOfBirth)
        vaccinations = try? container.decode([Vaccination].self, forKey: .vaccinations)
        tests = try? container.decode([Test].self, forKey: .tests)
        pastInfections = try? container.decode([PastInfection].self, forKey: .pastInfections)
    }
}

public enum ImmunisationType: String, Codable {
    case test = "t"
    case recovery = "r"
    case vaccination = "v"
}

public struct Person: Codable {
    public let givenName: String?
    public let standardizedGivenName: String?
    public let familyName: String?
    public let standardizedFamilyName: String

    private enum CodingKeys: String, CodingKey {
        case givenName = "gn"
        case standardizedGivenName = "gnt"
        case familyName = "fn"
        case standardizedFamilyName = "fnt"
    }
}

public struct Vaccination: Codable {
    public let disease: String
    public let vaccine: String
    public let medicinialProduct: String
    public let marketingAuthorizationHolder: String
    public let doseNumber: UInt64
    public let totalDoses: UInt64
    public let vaccinationDate: String
    public let country: String
    public let certificateIssuer: String
    public let certificateIdentifier: String

    private enum CodingKeys: String, CodingKey {
        case disease = "tg"
        case vaccine = "vp"
        case medicinialProduct = "mp"
        case marketingAuthorizationHolder = "ma"
        case doseNumber = "dn"
        case totalDoses = "sd"
        case vaccinationDate = "dt"
        case country = "co"
        case certificateIssuer = "is"
        case certificateIdentifier = "ci"
    }

    public var isTargetDiseaseCorrect: Bool {
        return disease == Disease.SarsCov2.rawValue
    }

    /// we need a date of vaccination which needs to be in the format of yyyy-MM-dd
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DATE_FORMAT
        return dateFormatter
    }

    public var dateOfVaccination: Date? {
        return dateFormatter.date(from: vaccinationDate)
    }

    public func getValidFromDate(singleVaccineValidityOffset: Int,
                                 twoVaccineValidityOffset: Int,
                                 totalDoses: Int) -> Date? {
        guard let dateOfVaccination = self.dateOfVaccination
        else {
            return nil
        }

        if totalDoses == 1 {
            return Calendar.current.date(byAdding: DateComponents(day: singleVaccineValidityOffset), to: dateOfVaccination)
        } else if totalDoses == 2 {
            return Calendar.current.date(byAdding: DateComponents(day: twoVaccineValidityOffset), to: dateOfVaccination)
        } else {
            // in any other case the vaccine is valid from the date of vaccination
            return dateOfVaccination
        }
    }

    public func getValidUntilDate(maximumValidityInDays: Int) -> Date? {
        guard let dateOfVaccination = self.dateOfVaccination,
              let date = Calendar.current.date(byAdding: DateComponents(day: maximumValidityInDays), to: dateOfVaccination) else {
            return nil
        }
        return date
    }

    public var name: String? {
        return ProductNameManager.shared.vaccineProductName(key: medicinialProduct)
    }

    public var authHolder: String? {
        return ProductNameManager.shared.vaccineManufacturer(key: marketingAuthorizationHolder)
    }

    public var prophylaxis: String? {
        return ProductNameManager.shared.vaccineProphylaxisName(key: vaccine)
    }
}

public struct Test: Codable {
    public let disease: String
    public let type: String
    public let naaTestName: String?
    public let ratTestNameAndManufacturer: String?
    public let timestampSample: String
    public let timestampResult: String?
    public let result: String
    public let testCenter: String?
    public let country: String
    public let certificateIssuer: String
    public let certificateIdentifier: String

    private enum CodingKeys: String, CodingKey {
        case disease = "tg"
        case type = "tt"
        case naaTestName = "nm"
        case ratTestNameAndManufacturer = "ma"
        case timestampSample = "sc"
        case timestampResult = "dr"
        case result = "tr"
        case testCenter = "tc"
        case country = "co"
        case certificateIssuer = "is"
        case certificateIdentifier = "ci"
    }

    public var validFromDate: Date? {
        return Date.fromISO8601(timestampSample)
    }

    public var resultDate: Date? {
        if let res = timestampResult {
            return Date.fromISO8601(res)
        }

        return nil
    }

    /// PCR tests are valid for 72h after sample collection. RAT tests are valid for 24h and have an optional validfrom. We just never set it
    public var validUntilDate: Date? {
        guard let startDate = validFromDate else { return nil }

        switch type {
        case TestType.Pcr.rawValue:
            return Calendar.current.date(byAdding: DateComponents(hour: PCR_TEST_VALIDITY_IN_HOURS), to: startDate)
        case TestType.Rat.rawValue:
            return Calendar.current.date(byAdding: DateComponents(hour: RAT_TEST_VALIDITY_IN_HOURS), to: startDate)
        default:
            return nil
        }
    }

    public func getValidUntilDate(pcrTestValidityInHours: Int, ratTestValidityInHours: Int) -> Date? {
        guard let startDate = validFromDate else { return nil }
        switch type {
        case TestType.Pcr.rawValue:
            return Calendar.current.date(byAdding: DateComponents(hour: pcrTestValidityInHours), to: startDate)
        case TestType.Rat.rawValue:
            return Calendar.current.date(byAdding: DateComponents(hour: ratTestValidityInHours), to: startDate)
        default:
            return nil
        }
    }

    public var isTargetDiseaseCorrect: Bool {
        return disease == Disease.SarsCov2.rawValue
    }

    public var isNegative: Bool {
        return result == TestResult.Negative.rawValue
    }

    public var testType: String? {
        return ProductNameManager.shared.testTypeName(key: type)
    }

    public var testName: String? {
        switch type {
        case TestType.Pcr.rawValue:
            return naaTestName ?? "PCR"
        case TestType.Rat.rawValue:
            return naaTestName
        default:
            return nil
        }
    }

    public var manufacturer: String? {
        if let val = ProductNameManager.shared.testManufacturerName(key: ratTestNameAndManufacturer) {
            var r = val.replacingOccurrences(of: naaTestName ?? "", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            if let last = r.last, last == "," {
                r.removeLast()
            }

            return r.isEmpty ? nil : r
        }

        return nil
    }
}

public struct PastInfection: Codable {
    public let disease: String
    public let dateFirstPositiveTest: String
    public let countryOfTest: String
    public let certificateIssuer: String
    public let validFrom: String
    public let validUntil: String
    public let certificateIdentifier: String

    private enum CodingKeys: String, CodingKey {
        case disease = "tg"
        case dateFirstPositiveTest = "fr"
        case countryOfTest = "co"
        case certificateIssuer = "is"
        case validFrom = "df"
        case validUntil = "du"
        case certificateIdentifier = "ci"
    }

    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DATE_FORMAT
        return dateFormatter
    }

    public var firstPositiveTestResultDate: Date? {
        return dateFormatter.date(from: dateFirstPositiveTest)
    }

    public var validFromDate: Date? {
        guard let firstPositiveTestResultDate = self.firstPositiveTestResultDate,
              let date = Calendar.current.date(byAdding: DateComponents(day: INFECTION_VALIDITY_OFFSET_IN_DAYS), to: firstPositiveTestResultDate) else {
            return nil
        }
        return date
    }

    public func getValidUntilDate(maximumValidityInDays: Int) -> Date? {
        guard let firstPositiveTestResultDate = self.firstPositiveTestResultDate,
              let date = Calendar.current.date(byAdding: DateComponents(day: maximumValidityInDays), to: firstPositiveTestResultDate) else {
            return nil
        }
        return date
    }

    public var isTargetDiseaseCorrect: Bool {
        return disease == Disease.SarsCov2.rawValue
    }
}
