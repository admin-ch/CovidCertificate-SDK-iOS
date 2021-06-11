//
//  File.swift
//  
//
//  Created by Patrick Amrein on 11.06.21.
//

import Foundation
import JSON
import jsonlogic

public enum CertLogicCommonError: String, Error {
    case RULE_PARSING_FAILED
}

public enum CertLogicValidationError : Error {
    case JSON_ERROR
    case TESTS_FAILED(tests: [String:String])
    case TEST_COULD_NOT_BE_PERFORMED(test: String)
}

public class CertLogic {
    var rules: [JSON] = []
    var valueSets: JSON = []
    
    public init() {}
    
    public init(data: Data) {
        let _ = self.updateData(requestBody: data)
    }
    
    private var now : String {
        return ISO8601DateFormatter().string(from: Date())
    }
    private var today : String {
        return ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
    }
    
    public func updateData(requestBody: Data) -> Result<(), CertLogicCommonError> {
        guard let logicRules = JSON(requestBody)["rules"].array else {
            return .failure(.RULE_PARSING_FAILED)
        }
        rules = logicRules
        valueSets = JSON(requestBody)["valueSets"]
        return .success(())
    }
    
    public func checkRules(hcert: EuHealthCert) -> Result<(), CertLogicValidationError> {
        var external = JSON(
            ["validationClock": now,
             "validationClockAtStartOfDay": today,
            ]
        )
        external["valueSets"] = valueSets
        var failedTests : [String: String] = [:]
        guard let dgcJson =  try? JSONEncoder().encode(hcert) else {
            return .failure(.JSON_ERROR)
        }
        var context = JSON(["external" : external, "payload" : JSON(dgcJson)])
        for rule in self.rules {
            let logic = rule["logic"]
            guard let result: Bool = try? applyRule(logic, to: context) else {
                return .failure(.TEST_COULD_NOT_BE_PERFORMED(test: rule["id"].string ?? "TEST_ID_UNKNOWN"))
            }
            if !result {
                failedTests.updateValue(rule["description"].string ?? "TEST_DESCRIPTION_UNKNOWN", forKey: rule["id"].string ?? "TEST_ID_UNKNOWN")
            }
        }
        if failedTests.isEmpty {
            return .success(())
        } else {
            return .failure(.TESTS_FAILED(tests: failedTests))
        }
    }
}
