#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'revenuecat'
  s.version          = '0.0.2'
  s.summary          = 'RevenueCat plugin for Flutter'
  s.description      = <<-DESC
RevenueCat plugin for Flutter
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Purchases', '~> 1.2.1'
  
#  s.ios.deployment_target = '8.0'
end

