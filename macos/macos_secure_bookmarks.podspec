#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint macos_secure_bookmarks.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'macos_secure_bookmarks'
  s.version          = '0.3.0'
  s.summary          = 'Flutter desktop plugin for managing secure bookmarks to access files in sandbox.'
  s.description      = <<-DESC
Flutter plugin to create security-scoped bookmarks and keep access to files in sandboxed macOS apps.
                       DESC
  s.homepage         = 'https://github.com/authpass/macos_secure_bookmarks'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AuthPass' => 'hello@authpass.app' }

  s.source           = { :path => '.' }
  s.source_files = 'macos_secure_bookmarks/Sources/macos_secure_bookmarks/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'macos_secure_bookmarks_privacy' => ['macos_secure_bookmarks/Sources/macos_secure_bookmarks/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
