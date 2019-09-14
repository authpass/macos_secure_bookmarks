#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'macos_secure_bookmarks'
  s.version          = '0.0.1'
  s.summary          = 'No-op implementation of macos_secure_bookmarks desktop plugin to avoid build issues on iOS'
  s.description      = <<-DESC
temp fake file_chooser plugin
                       DESC
  s.homepage         = 'https://github.com/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { '' => 'h@poul.at' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '8.0'
end

