Pod::Spec.new do |s|
  s.name                    = 'HeartbeatLoggingTestUtils'
  s.version                 = '8.11.0'
  s.summary                 = 'Testing utilities for testing the HeartbeatLogging module'

  s.description             = <<-DESC
  Type declarations and utilities needed for unit testing the HeartbeatLogging module.
  This podspec is for internal testing only and should not be published.
                         DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.3'

  ios_deployment_target     = '9.0'
  osx_deployment_target     = '10.12'
  tvos_deployment_target    = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.ios.deployment_target     = ios_deployment_target
  s.osx.deployment_target     = osx_deployment_target
  s.tvos.deployment_target    = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.requires_arc              = false

  s.framework = 'XCTest'
  s.osx.framework             = 'XCTest'
  s.ios.framework             = 'XCTest'
  s.tvos.framework            = 'XCTest'
  s.watchos.framework         = 'XCTest'

  s.cocoapods_version         = '>= 1.4.0'
  s.prefix_header_file        = false
  
  s.source_files = [
    'HeartbeatLoggingTestUtils/Sources/**/*.swift',
  ]

  

  s.pod_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO',
    'ENABLE_TESTING_SEARCH_PATHS' => 'YES',
    'DEFINES_MODULE' => 'YES'
  }

  s.dependency 'FirebaseCore', '~> 8.0'

end
