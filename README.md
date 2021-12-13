# CovidCertificate-SDK-iOS

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-%E2%9C%93-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://github.com/admin-ch/CovidCertificate-SDK-iOS/blob/main/LICENSE)
 
 ## Introduction

This is the implementation of the [Electronic Health Certificates (EHN) specification](https://github.com/ehn-digital-green-development/hcert-spec)
used to verify the validity of COVID Certificates [in Switzerland](https://github.com/admin-ch/CovidCertificate-App-iOS).

It is partly based on the reference implementation of EHN's `ValidationCore` [[2](https://github.com/ehn-digital-green-development/ValidationCore/tree/main/Sources/ValidationCore)]. 

## Contribution Guide

This project is truly open-source and we welcome any feedback on the code regarding both the implementation and security aspects.

Bugs or potential problems should be reported using Github issues.
We welcome all pull requests that improve the quality of the source code.

## Repositories

* iOS App: [CovidCertificate-App-iOS](https://github.com/admin-ch/CovidCertificate-App-iOS)
* Android App: [CovidCertificate-App-Android](https://github.com/admin-ch/CovidCertificate-App-Android)
* Android SDK: [CovidCertificate-SDK-Android](https://github.com/admin-ch/CovidCertificate-SDK-Android)
* For all others, see the [Github organisation](https://github.com/admin-ch/)
 
## Installation

### Swift Package Manager

CovidCertificateSDK is available through [Swift Package Manager](https://swift.org/package-manager)

1. Add the following to your `Package.swift` file:

  ```swift

  dependencies: [
      .package(url: "https://github.com/admin-ch/CovidCertificate-SDK-iOS.git", .branch("main"))
  ]

  ```

This version points to the HEAD of the `main` branch and will always fetch the latest development status. Releases will be made available using semantic versioning to ensure stability for depending projects.

### Cocoapods

CovidCertificateSDK is available through [Cocoapods](https://cocoapods.org/)

1. Add the following to your `Podfile`:

  ```ruby

  pod 'CovidCertificateSDK', '~> 1.0'

  ```

This version points to the HEAD of the `main` branch and will always fetch the latest development status. Releases will be made available using semantic versioning to ensure stability for depending projects.


## Summary: How the SDK works

The SDK provides the functionality of decoding a QR code into an electronic health certificate and verifying the validity of the decoded certificate.
It also takes care of loading and storing the latest trust list information that is required for verification. 
The trust list is a data model that contains a list of trusted public signing keys, a list of revoked certificate identifiers and the currently active national rules. 

### Decoding

Decoding a QR code into a COVID certificate uses the following steps. For more information, refer to the [EHN specification](https://ec.europa.eu/health/sites/default/files/ehealth/docs/digital-green-certificates_v1_en.pdf).
1. Check the prefix of the data. Only `HC1:` (EU Dcc Certificate) and `LT1:` (CH Certificate Light) are valid prefixes
2. Base45 decode the data <sup> [[1]](https://datatracker.ietf.org/doc/draft-faltstrom-base45/) </sup>
3. ZLIB decompress the data
4. COSE decode the data <sup> [[2]](https://github.com/eu-digital-green-certificates/SwiftCBOR) </sup>
5. CBOR decode the data and parse it into a `CertificateHolder` containing either a `DCCCert` or a `LightCert`

### Verification

The verification process consists of three parts that need to be successful in order for a certificate to be considered valid.
1. The certificate signature is verified against a list of trusted public keys from issueing countries
2. The UVCI (unique vaccination certificate identifier) is compared to a list of revoked certificates to ensure the certificate has not been revoked
3. The certificate details are checked based on the Swiss national rules for certificate validity. (Is the number of vaccination doses sufficient, is the test recent enough, how long ago was the recovery?)

## Usage: How to use the SDK

The SDK needs to be initialized with an environment and a API token. 
This allows for different verification rules per environment or other environment-specific settings.

If you intend to integrate the CovidCertificate-SDK-iOS into your app, please get in touch with the [BAG](mailto:Covid-Zertifikat@bag.admin.ch) to get a token assigned.

After initialization the following pipeline should be used:

1) Decode the base45 and prefixed string to retrieve a Digital Covid Certificate

2) Verify the Certificate by calling the `.check` method. Internally this verifies the signature, revocation status and national rules

All these checks check against verification properties that are loaded from a server. 
These returned properties use a property to specify how long they are valid (like `max-age` in general networking). 
With the parameter `forceUpdate`, these properties can be forced to update.

CovidCertificateSDK offers a `Verifier` and `Wallet` namespace. Methods in the Wallet namespace must only be used by the official COVID Certificate App.

### Decoding
```swift
let result: Result<VerifierCertificateHolder, CovidCertError> = CovidCertificateSDK.Verifier.decode(encodedData: qrCodeString)
```

### Verification
```swift
CovidCertificateSDK.Verifier.check(holder: certificateHolder, mode: checkMode) { result: CheckResults in
        result.signatureResult
        result.revocationStatus
        result.nationalRules
        result.modeResults                                                                        
}
```

#### Verification Modes

 A verification mode collects together a set of verification rules.
 Examples of verification modes are "2G", "3G".

 Unlike you might expect, the SDK does NOT hardcode the different verification modes into an enum.
 Instead, they are provided dynamically by the backend.
 This in order to integrate with the CertLogic rules that drive the verification process (which are also provided dynamically).

 DO NOT hardcode the verification modes! If the backend changes the available modes, your app may crash!

 To obtain a list of currently available verification modes:

 ```kotlin
 var activeModes: [CheckMode] = CovidCertificateSDK.supportedModes
 ```

## License

This project is licensed under the terms of the MPL 2 license. See the [LICENSE](LICENSE) file for details.

## References
[[1](https://github.com/ehn-digital-green-development/hcert-spec)] Health Certificate Specification

[[2](https://github.com/ehn-digital-green-development/ValidationCore/tree/main/Sources/ValidationCore)] Validation Core
