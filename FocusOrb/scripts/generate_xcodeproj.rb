#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'FocusOrb.xcodeproj')

FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastUpgradeCheck'] = '1700'
project.root_object.attributes['LastSwiftUpdateCheck'] = '1700'

app_target = project.new_target(:application, 'FocusOrb', :osx, '14.0')
app_target.product_name = 'FocusOrb'

project.build_configurations.each do |config|
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['MARKETING_VERSION'] = '1.0.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['SWIFT_VERSION'] = '5.9'
end

app_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.focusorb.app'
  settings['INFOPLIST_FILE'] = 'Info.plist'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'FocusOrb.entitlements'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  settings['SWIFT_VERSION'] = '5.9'
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  settings['MARKETING_VERSION'] = '1.0.0'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  settings['ENABLE_HARDENED_RUNTIME'] = 'YES' if config.name == 'Release'
end

main_group = project.main_group

swift_sources = Dir.glob(File.join(root, 'Sources/**/*.swift')).sort
localized_resources = Dir.glob(File.join(root, 'Sources/Resources/**/*.lproj/*')).select do |path|
  File.file?(path) && %w[.strings .stringsdict].include?(File.extname(path))
end.sort
resource_entries = [
  File.join(root, 'Sources/Resources/Assets.xcassets'),
  File.join(root, 'Sources/Resources/PrivacyInfo.xcprivacy')
] + Dir.glob(File.join(root, 'Sources/Resources/Orb/*.png')).sort + localized_resources

(swift_sources + resource_entries + [File.join(root, 'Info.plist'), File.join(root, 'FocusOrb.entitlements')]).each do |abs_path|
  rel_path = Pathname(abs_path).relative_path_from(Pathname(root)).to_s
  main_group.new_reference(rel_path)
end

swift_sources.each do |abs_path|
  rel_path = Pathname(abs_path).relative_path_from(Pathname(root)).to_s
  file_ref = project.files.find { |f| f.path == rel_path }
  app_target.source_build_phase.add_file_reference(file_ref) if file_ref
end

resource_entries.each do |abs_path|
  rel_path = Pathname(abs_path).relative_path_from(Pathname(root)).to_s
  file_ref = project.files.find { |f| f.path == rel_path }
  app_target.resources_build_phase.add_file_reference(file_ref) if file_ref
end

# Swift package dependency: GRDB
package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
package_ref.repositoryURL = 'https://github.com/groue/GRDB.swift.git'
package_ref.requirement = {
  'kind' => 'upToNextMajorVersion',
  'minimumVersion' => '6.0.0'
}
project.root_object.package_references << package_ref

package_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
package_product.package = package_ref
package_product.product_name = 'GRDB'
app_target.package_product_dependencies << package_product

framework_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
framework_build_file.product_ref = package_product
app_target.frameworks_build_phase.files << framework_build_file

# Shared scheme for CLI builds
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.set_launch_target(app_target)
scheme.save_as(project_path, 'FocusOrb', true)

project.save
puts "Generated #{project_path}"
