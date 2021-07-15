Pod::Spec.new do |spec|
  spec.name         = "CovidCertificateSDK"
  
  spec.version      = ENV['LIB_VERSION'] || '1.0.0'

  spec.summary      = "Implementation of the Electronic Health Certificates (EHN) specification used to verify the validity of COVID Certificates in Switzerland."

  spec.homepage     = "https://github.com/admin-ch/CovidCertificate-SDK-iOS"

  spec.license      = { :type => "MPL", :file => "LICENSE" }

  spec.author       = { "ubique" => "covidcertificate@ubique.ch" }

  spec.platform     = :ios, "13.7"

  spec.swift_versions = "5.2"

  spec.source       = { :git => "https://github.com/admin-ch/CovidCertificate-SDK-iOS.git", :branch => "main" }

  spec.source_files  = "Sources/CovidCertificateSDK", "Sources/CovidCertificateSDK/**/*.{h,m,swift}"

end