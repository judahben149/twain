Pod::Spec.new do |s|
  s.name             = 'wallpaper_sync_plugin'
  s.version          = '0.0.1'
  s.summary          = 'iOS wallpaper sync plugin for Twain.'
  s.description      = 'Saves synced wallpapers to an App Group container and exposes them via App Intents for Siri Shortcuts.'
  s.homepage         = 'https://github.com/judahben149/twain'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Twain' => 'dev@twain.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
