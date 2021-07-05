//
//  ValidationResult.swift
//
//
//  Created by Dominik Mocher on 07.04.21.
//

import Foundation

public struct ValidationResult {
    public let isValid: Bool
    public let payload: CovidCertificate
    public let error: ValidationError?
}
