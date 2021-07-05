# CovidCertificate-SDK-iOS

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-%E2%9C%93-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://github.com/admin-ch/CovidCertificate-SDK-iOS/blob/main/LICENSE)
 
 ## Introduction

This is the Swiss implementation of the Electronic Health Certificates (EHN) Specification [[1](https://github.com/ehn-digital-green-development/hcert-spec)] used to verify the validity of Digital Covid Certificates. It is partly based on the reference implementation of EHN's `ValidationCore` [[2](https://github.com/ehn-digital-green-development/ValidationCore/tree/main/Sources/ValidationCore)]. 
 
 ## Work in Progress

The CovidCertificateSDK for iOS is work in progress and is not yet complete. We are continuing the development of this library, and the API is likely to change. Please contact the BIT before using / integrating this SDK in your app.
 
## Installation

### Swift Package Manager

CrowdNotifierSDK is available through [Swift Package Manager](https://swift.org/package-manager)

1. Add the following to your `Package.swift` file:

  ```swift

  dependencies: [
      .package(url: "https://github.com/admin-ch/CovidCertificate-SDK-iOS.git", .branch("main"))
  ]

  ```

This version points to the HEAD of the `main` branch and will always fetch the latest development status. Future releases will be made available using semantic versioning to ensure stability for depending projects.


 ## Architecture

The SDK needs to be initialized with an environment. This allows for different verification rules per environment or other environment-specific settings.

After initialization the following pipeline should be used:

1) Decode the base45 and prefixed string to retrieve a Digital Covid Certificate

2) Verify the Certificate by calling the `.check` method. Internally this verifies the signature, revocation status and national rules

All these checks check against verification properties that are loaded from a server. These returned properties use a property to specify how long they are valid (like `max-age` in general networking). With the parameter `forceUpdate`, these properties can be forced to update.

CovidCertificateSDK offers a `Verifier` and `Wallet` namespace. Methods in the Wallet namespace must only be used by the official COVID Certificate App.

### Decoding
```swift
let result: Result<VerifierCertificateHolder, CovidCertError> = CovidCertificateSDK.Verifier.decode(encodedData: qrCodeString)
```

### Verification
```swift
CovidCertificateSDK.Verifier.check(holder: certificateHolder) { result: CheckResults in
        result.signatureResult
        result.revocationStatus
        result.nationalRules
}
```

 ## References
[[1](https://github.com/ehn-digital-green-development/hcert-spec)] Health Certificate Specification

[[2](https://github.com/ehn-digital-green-development/ValidationCore/tree/main/Sources/ValidationCore)] Validation Core
