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
        if let v = vaccinations, v.count >= 1 {
            return .vaccination
        } else if let p = pastInfections, p.count >= 1 {
            return .recovery
        } else if let tests = tests, tests.count >= 1 {
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
        version = try container.decode(String.self, forKey: .version).trimmed
        dateOfBirth = try container.decode(String.self, forKey: .dateOfBirth).trimmed
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        givenName = try? container.decode(String.self, forKey: .givenName).trimmed
        standardizedGivenName = try? container.decode(String.self, forKey: .standardizedGivenName).trimmed
        familyName = try? container.decode(String.self, forKey: .familyName).trimmed
        standardizedFamilyName = try container.decode(String.self, forKey: .standardizedFamilyName).trimmed
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        disease = try container.decode(String.self, forKey: .disease).trimmed
        vaccine = try container.decode(String.self, forKey: .vaccine).trimmed
        medicinialProduct = try container.decode(String.self, forKey: .medicinialProduct).trimmed
        marketingAuthorizationHolder = try container.decode(String.self, forKey: .marketingAuthorizationHolder).trimmed

        if let dn = try? container.decode(Double.self, forKey: .doseNumber) {
            doseNumber = UInt64(dn)
        } else {
            doseNumber = try container.decode(UInt64.self, forKey: .doseNumber)
        }

        if let dn = try? container.decode(Double.self, forKey: .totalDoses) {
            totalDoses = UInt64(dn)
        } else {
            totalDoses = try container.decode(UInt64.self, forKey: .totalDoses)
        }

        vaccinationDate = try container.decode(String.self, forKey: .vaccinationDate).trimmed
        country = try container.decode(String.self, forKey: .country).trimmed
        certificateIssuer = try container.decode(String.self, forKey: .certificateIssuer).trimmed
        certificateIdentifier = try container.decode(String.self, forKey: .certificateIdentifier).trimmed
    }

    public var isTargetDiseaseCorrect: Bool {
        disease == Disease.SarsCov2.rawValue
    }

    public var dateOfVaccination: Date? {
        DateFormatter.dayDateFormatter.date(from: vaccinationDate)
    }

    public func getValidFromDate(singleVaccineValidityOffset: Int,
                                 twoVaccineValidityOffset: Int,
                                 totalDoses: Int) -> Date? {
        guard let dateOfVaccination = dateOfVaccination
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
        guard let dateOfVaccination = dateOfVaccination,
              let date = Calendar.current.date(byAdding: DateComponents(day: maximumValidityInDays), to: dateOfVaccination) else {
            return nil
        }
        return date
    }

    public var name: String? {
        ProductNameManager.shared.vaccineProductName(key: medicinialProduct)
    }

    public var authHolder: String? {
        ProductNameManager.shared.vaccineManufacturer(key: marketingAuthorizationHolder)
    }

    public var prophylaxis: String? {
        ProductNameManager.shared.vaccineProphylaxisName(key: vaccine)
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        disease = try container.decode(String.self, forKey: .disease).trimmed
        type = try container.decode(String.self, forKey: .type).trimmed
        naaTestName = try? container.decode(String.self, forKey: .naaTestName).trimmed
        ratTestNameAndManufacturer = try? container.decode(String.self, forKey: .ratTestNameAndManufacturer).trimmed
        timestampSample = try container.decode(String.self, forKey: .timestampSample).trimmed
        timestampResult = try? container.decode(String.self, forKey: .timestampResult).trimmed
        result = try container.decode(String.self, forKey: .result).trimmed
        testCenter = try? container.decode(String.self, forKey: .testCenter).trimmed
        country = try container.decode(String.self, forKey: .country).trimmed
        certificateIssuer = try container.decode(String.self, forKey: .certificateIssuer).trimmed
        certificateIdentifier = try container.decode(String.self, forKey: .certificateIdentifier).trimmed
    }

    public var validFromDate: Date? {
        Date.fromISO8601(timestampSample)
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
        disease == Disease.SarsCov2.rawValue
    }

    public var isNegative: Bool {
        result == TestResult.Negative.rawValue
    }

    public var isSerologicalTest: Bool {
        type == TestType.Serological.rawValue
    }

    public var isSwitzerlandException: Bool {
        type == TestType.SwitzerlandException.rawValue
    }

    public var testType: String? {
        ProductNameManager.shared.testTypeName(key: type)
    }

    public var manufacturerAndTestName: String? {
        switch type {
        case TestType.Pcr.rawValue:
            return naaTestName ?? "PCR"
        case TestType.Rat.rawValue:
            return ProductNameManager.shared.testManufacturerName(key: ratTestNameAndManufacturer) ?? ratTestNameAndManufacturer
        default:
            return nil
        }
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        disease = try container.decode(String.self, forKey: .disease).trimmed
        dateFirstPositiveTest = try container.decode(String.self, forKey: .dateFirstPositiveTest).trimmed
        countryOfTest = try container.decode(String.self, forKey: .countryOfTest).trimmed
        certificateIssuer = try container.decode(String.self, forKey: .certificateIssuer).trimmed
        validFrom = try container.decode(String.self, forKey: .validFrom).trimmed
        validUntil = try container.decode(String.self, forKey: .validUntil).trimmed
        certificateIdentifier = try container.decode(String.self, forKey: .certificateIdentifier).trimmed
    }

    public var firstPositiveTestResultDate: Date? {
        DateFormatter.dayDateFormatter.date(from: dateFirstPositiveTest)
    }

    public var validFromDate: Date? {
        guard let firstPositiveTestResultDate = firstPositiveTestResultDate,
              let date = Calendar.current.date(byAdding: DateComponents(day: INFECTION_VALIDITY_OFFSET_IN_DAYS), to: firstPositiveTestResultDate) else {
            return nil
        }
        return date
    }

    public func getValidUntilDate(maximumValidityInDays: Int) -> Date? {
        guard let firstPositiveTestResultDate = firstPositiveTestResultDate,
              let date = Calendar.current.date(byAdding: DateComponents(day: maximumValidityInDays), to: firstPositiveTestResultDate) else {
            return nil
        }
        return date
    }

    public var isTargetDiseaseCorrect: Bool {
        disease == Disease.SarsCov2.rawValue
    }
}
