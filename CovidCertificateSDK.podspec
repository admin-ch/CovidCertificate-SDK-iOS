Pod::Spec.new do |spec|
  spec.name         = "CovidCertificateSDK"
  spec.version      = ENV['LIB_VERSION'] || '1.0.0'
  spec.summary      = "Implementation of the Electronic Health Certificates (EHN) specification used to verify the validity of COVID Certificates in Switzerland."
  spec.homepage     = "https://github.com/admin-ch/CovidCertificate-SDK-iOS"
  spec.license      = { :type => "MPL", :file => "LICENSE" }
  spec.author       = { "ubique" => "covidcertificatesdk@ubique.ch" }
  spec.platform     = :ios, "12.0"
  spec.swift_versions = "5.3"
  spec.source       = { :git => "https://github.com/admin-ch/CovidCertificate-SDK-iOS.git", :branch => "feature/cocoapods" }
  spec.source_files  = "Sources/CovidCertificateSDK", "Sources/CovidCertificateSDK/**/*.{h,m,swift}"
  spec.resource_bundles = {'CovidCertificateSDK' => ['Sources/CovidCertificateSDK/Resources/*'] }

  spec.dependency "GzipSwift", "~>5.1.1"
  spec.dependency "SwiftJWT", "~>3.6.1"
  spec.dependency "SwiftCBOR"
  spec.dependency "base45-swift"
  spec.dependency "jsonlogicFork", "~>1.2.0"
end
