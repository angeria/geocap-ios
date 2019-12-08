# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'GeoCap' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for GeoCap
  pod 'Firebase/Firestore'
  pod 'Firebase/Messaging'
  pod 'Firebase/Auth'
  pod 'Firebase/Analytics'
  pod 'Firebase/Functions'
  pod 'Firebase/RemoteConfig'
  pod 'Firebase/Storage'
  pod 'Fabric', '~> 1.10.2'
  pod 'Crashlytics', '~> 3.14.0'

  pod 'ThirdPartyMailer'
  pod 'SnapSDK', :subspecs => ['SCSDKLoginKit', 'SCSDKBitmojiKit']
  pod 'SwiftEntryKit'

  target 'GeoCapTests' do
    inherit! :search_paths
    # Pods for testing
   end

end

target 'GeoCapUITests' do
  inherit! :search_paths
  # Pods for testing
end