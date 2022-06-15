// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CovidCertificateSDK",
    platforms: [
        .iOS(.v11),
        .macOS("10.14"),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CovidCertificateSDK",
            targets: ["CovidCertificateSDK"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "Gzip", url: "https://github.com/1024jp/GzipSwift", .upToNextMajor(from: "5.1.1")),
        .package(name: "SwiftJWT", url: "https://github.com/Kitura/Swift-JWT.git", from: "3.6.1"),
        .package(url: "https://github.com/eu-digital-green-certificates/SwiftCBOR", from: "0.4.4"),
        .package(url: "https://github.com/ehn-digital-green-development/base45-swift", from: "1.0.1"),
        .package(name: "JsonLogic", url: "https://github.com/eu-digital-green-certificates/json-logic-swift", .upToNextMajor(from: "1.1.8")),
        .package(name: "SQLite.swift", url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CovidCertificateSDK",
            dependencies: ["Gzip", "SwiftCBOR", "base45-swift", "SwiftJWT", "JsonLogic", .product(name: "SQLite", package: "SQLite.swift")],
            exclude: ["ehn/LICENSE.txt", "Helpers/Bundle+Loader.swift"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "CovidCertificateSDKTests",
            dependencies: ["CovidCertificateSDK", "JsonLogic"],
            resources: [
                .process("NationalRules"),
            ]
        ),
    ]
)
