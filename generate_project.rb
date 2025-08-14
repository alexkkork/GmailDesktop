require "xcodeproj"

project_path = "GmailDesktop.xcodeproj"
project = Xcodeproj::Project.new(project_path)

app_target = project.new_target(:application, "GmailDesktop", :osx, "13.0", nil, :swift)

app_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.alex.GmailDesktop"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["DEVELOPMENT_TEAM"] = ""
  config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "13.0"
  config.build_settings["INFOPLIST_FILE"] = "Info.plist"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
end

main_group = project.main_group

swift_files = [
  "GmailDesktopApp.swift",
  "ContentView.swift",
  "GmailWebView.swift",
  "NotificationManager.swift"
]

swift_refs = swift_files.map { |path| main_group.new_file(path) }

swift_refs.each do |ref|
  app_target.source_build_phase.add_file_reference(ref)
end

# Link WebKit framework
frameworks_group = project.frameworks_group
webkit_ref = frameworks_group.new_file("System/Library/Frameworks/WebKit.framework", :sdk_root)
app_target.frameworks_build_phase.add_file_reference(webkit_ref, true)

# Add Assets.xcassets to Resources
assets_path = "Assets.xcassets"
assets_ref = main_group.new_file(assets_path)
app_target.resources_build_phase.add_file_reference(assets_ref)

project.save
