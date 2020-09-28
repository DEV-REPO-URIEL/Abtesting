Pod::Spec.new do |s|
  s.name             = 'Firebase'
  s.version          = '6.33.0'
  s.summary          = 'Firebase'

  s.description      = <<-DESC
Simplify your app development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.preserve_paths = [
    "CoreOnly/CHANGELOG.md",
    "CoreOnly/NOTICES",
    "CoreOnly/README.md"
  ]
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.ios.dependency 'FirebaseAnalytics', '6.8.3'
    ss.dependency 'Firebase/CoreOnly'
  end

  s.subspec 'CoreOnly' do |ss|
    ss.dependency 'FirebaseCore', '6.10.3'
    ss.source_files = 'CoreOnly/Sources/Firebase.h'
    ss.preserve_paths = 'CoreOnly/Sources/module.modulemap'
    if ENV['FIREBASE_POD_REPO_FOR_DEV_POD'] then
      ss.user_target_xcconfig = {
        'HEADER_SEARCH_PATHS' => "$(inherited) \"" + ENV['FIREBASE_POD_REPO_FOR_DEV_POD'] + "/CoreOnly/Sources\""
      }
    else
      ss.user_target_xcconfig = {
        'HEADER_SEARCH_PATHS' => "$(inherited) ${PODS_ROOT}/Firebase/CoreOnly/Sources"
      }
    end
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '9.0'
    ss.osx.deployment_target = '10.12'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'Analytics' do |ss|
    ss.ios.deployment_target = '9.0'
    ss.dependency 'Firebase/Core'
  end

  s.subspec 'ABTesting' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseABTesting', '~> 4.2.0'
  end

  s.subspec 'AdMob' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.deployment_target = '9.0'
    ss.ios.dependency 'Google-Mobile-Ads-SDK', '~> 7.63'
  end

  s.subspec 'AppDistribution' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseAppDistribution', '~> 0.9.3'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'Auth' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseAuth', '~> 6.9.2'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '8.0'
    ss.osx.deployment_target = '10.11'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'Crashlytics' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseCrashlytics', '~> 4.6.1'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '8.0'
    ss.osx.deployment_target = '10.11'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'Database' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseDatabase', '~> 6.6.0'
  end

  s.subspec 'DynamicLinks' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseDynamicLinks', '~> 4.3.1'
  end

  s.subspec 'Firestore' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseFirestore', '~> 1.18.0'
  end

  s.subspec 'Functions' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseFunctions', '~> 2.9.0'
  end

  s.subspec 'InAppMessaging' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseInAppMessaging', '~> 0.24.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'Messaging' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseMessaging', '~> 4.7.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '10.0'
    ss.osx.deployment_target = '10.12'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'Performance' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebasePerformance', '~> 3.3.0'
  end

  s.subspec 'RemoteConfig' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseRemoteConfig', '~> 4.9.0'
  end

  s.subspec 'Storage' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseStorage', '~> 3.9.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '10.0'
    ss.osx.deployment_target = '10.12'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'MLCommon' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLCommon', '~> 0.21.0'
  end

  s.subspec 'MLModelInterpreter' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLModelInterpreter', '~> 0.22.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLVision' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVision', '~> 0.21.0'
  end

end
