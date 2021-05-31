# CovidCertificateVerifierSDK for iOS

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-%E2%9C%93-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://github.com/admin-ch/CovidCertificate-SDK-iOS/blob/main/LICENSE)
 
 ## Introduction

This is the Swiss implementation of the Electronic Healt Certificates Specification [[1](https://github.com/ehn-digital-green-development/hcert-spec)] used for the Digital Covid Certificates. It is based on the reference Implementation `ValidationCore` [[2](https://github.com/ehn-digital-green-development/ValidationCore/tree/main/Sources/ValidationCore)]. 
 ## Architecture

The SDK needs to be initialized with an environment. This allows for different verification rules per environment or other environment specific settings.

After initialization the following pipeline should be used:

1) Decode the base45 and prefixed string to retrieve a Digital Covid Certificate

2) Verify the signature of the Certificate

3) Check the revocation list. Currently always returns a valid `ValidationResult`

4) Check for rules specific to countries such as validity of vaccines or tests

### Decoding
```swift
public func decode(encodedData: String) -> Result<DGCHolder, CovidCertError>
```

### Verify Signature
```swift
public static func checkSignature(cose: DGCHolder, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void)
```

### Check Revocation List
Currently only stubs
```swift
public static func checkRevocationStatus(dgc: EuHealthCert, _ completionHandler: @escaping (Result<ValidationResult, ValidationError>) -> Void)
```

### Check National Specific Rules
```swift
public static func checkNationalRules(dgc: EuHealthCert, _ completionHandler: @escaping (Result<VerificationResult, NationalRulesError>) -> Void)
```

 ## References
[[1](https://github.com/ehn-digital-green-development/hcert-spec)] Health Certificate Specification

[[2](https://github.com/ehn-digital-green-development/ValidationCore/tree/main/Sources/ValidationCore)] Validation Core