#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'xcodeproj'

ROOT = Pathname.new(__dir__).parent.expand_path
PROJECT_PATH = ROOT.join('Orbit.xcodeproj')

PACKAGES = [
  {
    url: 'https://github.com/pointfreeco/swift-composable-architecture',
    minimum_version: '1.16.0',
    products: ['ComposableArchitecture'],
  },
  {
    url: 'https://github.com/pointfreeco/swift-case-paths',
    minimum_version: '1.5.0',
    products: ['CasePaths'],
  },
  {
    url: 'https://github.com/pointfreeco/swift-dependencies',
    minimum_version: '1.8.0',
    products: ['Dependencies'],
  },
  {
    url: 'https://github.com/pointfreeco/sqlite-data',
    minimum_version: '1.0.0',
    products: ['SQLiteData'],
  },
  {
    url: 'https://github.com/pointfreeco/swift-structured-queries',
    minimum_version: '0.1.0',
    products: ['StructuredQueries'],
  },
].freeze

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH.to_s)

sources_root = project.main_group.new_group('Sources', 'Sources')
orbit_sources_group = sources_root.new_group('OrbitApp', 'OrbitApp')
resources_group = project.main_group.new_group('Resources', 'Resources')

target = project.new_target(:application, 'Orbit', :osx, '14.0')

def add_swift_sources(group:, source_dir:, target:)
  Dir.children(source_dir).sort.each do |name|
    next if name.start_with?('.')

    full_path = File.join(source_dir, name)

    if File.directory?(full_path)
      subgroup = group.new_group(name, name)
      add_swift_sources(group: subgroup, source_dir: full_path, target: target)
      next
    end

    next unless File.extname(name) == '.swift'

    file_ref = group.new_file(name)
    target.source_build_phase.add_file_reference(file_ref, true)
  end
end

add_swift_sources(
  group: orbit_sources_group,
  source_dir: ROOT.join('Sources/OrbitApp').to_s,
  target: target
)

assets_ref = resources_group.new_file('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets_ref, true)

def add_swift_package_dependency(project:, target:, url:, minimum_version:, product_name:)
  package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package_ref.repositoryURL = url
  package_ref.requirement = {
    'kind' => 'upToNextMajorVersion',
    'minimumVersion' => minimum_version,
  }
  project.root_object.package_references << package_ref

  product_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dependency.package = package_ref
  product_dependency.product_name = product_name
  target.package_product_dependencies << product_dependency

  framework_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  framework_build_file.product_ref = product_dependency
  target.frameworks_build_phase.files << framework_build_file

  target_dependency = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
  target_dependency.product_ref = product_dependency
  target.dependencies << target_dependency
end

PACKAGES.each do |package|
  package[:products].each do |product_name|
    add_swift_package_dependency(
      project: project,
      target: target,
      url: package[:url],
      minimum_version: package[:minimum_version],
      product_name: product_name
    )
  end
end

project.build_configurations.each do |config|
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
end

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'Orbit'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.smiller.orbit'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['INFOPLIST_KEY_LSUIElement'] = 'YES'
  config.build_settings['INFOPLIST_KEY_NSHumanReadableCopyright'] = 'Copyright © 2026 Orbit'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Orbit'
  config.build_settings['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.productivity'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil, launch_target: true)
scheme.save_as(PROJECT_PATH, 'Orbit', true)

project.save
puts "Generated #{PROJECT_PATH}"
