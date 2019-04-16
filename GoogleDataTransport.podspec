Pod::Spec.new do |s|
  s.name             = 'GoogleDataTransport'
  s.version          = '0.1.0'
  s.summary          = 'Google iOS SDK data transport.'

  s.description      = <<-DESC
Shared library for iOS SDK data transport needs.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'GoogleDataTransport-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'

  # To develop or run the tests, >= 1.6.0 must be installed.
  s.cocoapods_version = '>= 1.4.0'

  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'GoogleDataTransport/Library/**/*'
  s.public_header_files = 'GoogleDataTransport/Library/Public/*.h'
  s.private_header_files = 'GoogleDataTransport/Library/Private/*.h'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
    'CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY' => 'YES'
  }

  common_test_sources = ['GoogleDataTransport/Tests/Common/**/*.{h,m}']
  common_test_settings = { 'HEADER_SEARCH_PATHS' => __dir__ + '/GoogleDataTransport/Library/' }

  # Unit test specs
  s.test_spec 'Tests-Unit' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/Tests/Unit/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = common_test_settings
  end

  s.test_spec 'Tests-Lifecycle' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/Tests/Lifecycle/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = common_test_settings
  end

  # Integration test specs
  s.test_spec 'Tests-Integration' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/Tests/Integration/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = common_test_settings
    test_spec.dependency 'GCDWebServer'
  end
end
