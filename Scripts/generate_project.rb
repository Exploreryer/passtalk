#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'xcodeproj'

repo_root = File.expand_path('..', __dir__)
project_path = File.join(repo_root, 'PassTalk.xcodeproj')

FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)

app_target = project.new_target(:application, 'PassTalkApp', :ios, '16.0')
test_target = project.new_target(:unit_test_bundle, 'PassTalkTests', :ios, '16.0')

app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.passtalk.app'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'PassTalk'
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone'] = 'UIInterfaceOrientationPortrait'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  config.build_settings['OTHER_LDFLAGS'] = ['$(inherited)', '-lsqlite3']
end
app_target.add_system_framework('Security.framework')

main_group = project.main_group

Dir.glob(File.join(repo_root, 'PassTalkApp/**/*.swift')).sort.each do |path|
  relative = Pathname.new(path).relative_path_from(Pathname.new(repo_root)).to_s
  ref = main_group.new_file(relative)
  app_target.add_file_references([ref])
end

Dir.glob(File.join(repo_root, 'PassTalkTests/**/*.swift')).sort.each do |path|
  relative = Pathname.new(path).relative_path_from(Pathname.new(repo_root)).to_s
  ref = main_group.new_file(relative)
  test_target.add_file_references([ref])
end

test_target.add_dependency(app_target)

test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.passtalk.app.tests'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/PassTalkApp.app/PassTalkApp'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
  config.build_settings['OTHER_LDFLAGS'] = ['$(inherited)', '-lsqlite3']
end

project.recreate_user_schemes
project.save
puts "Generated #{project_path}"
