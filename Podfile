# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

target 'GeoCap' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for GeoCap
  pod 'Protobuf', :inhibit_warnings => true

  pod 'Firebase/Firestore'
  pod 'Firebase/Functions'
  pod 'Firebase/Messaging'

  pod 'FirebaseUI/Auth'
  pod 'FirebaseUI/Email'
  pod 'FirebaseUI/Facebook'
  pod 'FirebaseUI/Google'

  target 'GeoCapTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'GeoCapUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
    puts 'Removing static analyzer support'
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['OTHER_CFLAGS'] = "$(inherited) -Qunused-arguments -Xanalyzer -analyzer-disable-all-checks"
        end
    end
end
