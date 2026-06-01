#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint purchasely_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'purchasely_flutter'
  s.version          = '1.2.4'
  s.summary          = 'Flutter Plugin for Purchasely SDK'
  s.description      = <<-DESC
Flutter Plugin for Purchasely SDK
                       DESC
  s.homepage         = 'https://www.purchasely.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'mathieu@purchasely.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.4'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Pinned to the Purchasely 6.0 SDK — the single plugin
  # (SwiftPurchaselyFlutterPlugin.swift) depends on the 6.0 builder DSL
  # (Purchasely.apiKey(...).start), PLYPresentationBuilder,
  # PLYPresentationRequest, and the interceptAction(_:handler:) overload.
  s.dependency 'Purchasely', '6.0.0'
  s.static_framework = true

end
