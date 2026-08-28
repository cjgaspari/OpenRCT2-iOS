# OpenRCT2 Touch iPhone and iPad application shell.

if (NOT TARGET SDL2::SDL2main)
    message(FATAL_ERROR "SDL2 did not provide the UIKit SDL2main target")
endif ()

set(OPENRCT2_TOUCH_ASSET_CATALOG "${CMAKE_CURRENT_LIST_DIR}/App/Assets.xcassets")

set(_openrct2_touch_sources
    "${CMAKE_CURRENT_LIST_DIR}/App/AppLifecycle.iOS.mm"
    "${CMAKE_CURRENT_LIST_DIR}/platform/RCT2Importer.iOS.mm"
    "${CMAKE_CURRENT_LIST_DIR}/platform/chrome/OpenRCT2TouchSwiftRuntime.swift")
if (CMAKE_GENERATOR STREQUAL "Xcode")
    list(APPEND _openrct2_touch_sources "${OPENRCT2_TOUCH_ASSET_CATALOG}")
endif ()

add_executable(openrct2-touch MACOSX_BUNDLE ${_openrct2_touch_sources})

set_source_files_properties(
    "${CMAKE_CURRENT_LIST_DIR}/App/AppLifecycle.iOS.mm"
    "${CMAKE_CURRENT_LIST_DIR}/platform/RCT2Importer.iOS.mm"
    PROPERTIES COMPILE_FLAGS "-fno-objc-arc")

if (CMAKE_GENERATOR STREQUAL "Xcode")
    set_source_files_properties("${OPENRCT2_TOUCH_ASSET_CATALOG}" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)
endif ()

option(OPENRCT2_IOS_CODE_SIGNING "Allow Xcode to sign the iPadOS app" OFF)
set(OPENRCT2_IOS_DEVELOPMENT_TEAM "" CACHE STRING "Apple development team used only for a signed iPadOS build")
option(OPENRCT2_BUNDLE_LOCAL_RCT2 "Copy ignored ref/rct2 into the local .app before codesign (personal installs only)" OFF)

if (OPENRCT2_IOS_CODE_SIGNING)
    if (NOT CMAKE_GENERATOR STREQUAL "Xcode")
        message(FATAL_ERROR "OPENRCT2_IOS_CODE_SIGNING requires the Xcode generator")
    endif ()
    if (OPENRCT2_IOS_DEVELOPMENT_TEAM STREQUAL "")
        message(FATAL_ERROR "OPENRCT2_IOS_DEVELOPMENT_TEAM is required when iPadOS code signing is enabled")
    endif ()
    set(OPENRCT2_IOS_CODE_SIGNING_ALLOWED YES)
else ()
    set(OPENRCT2_IOS_CODE_SIGNING_ALLOWED NO)
endif ()

target_link_libraries(openrct2-touch PRIVATE
    SDL2::SDL2main
    OpenRCT2::openrct2-ui
    "-framework SwiftUI"
    "-framework Combine")
set_target_properties(openrct2-touch PROPERTIES
    Swift_MODULE_NAME OpenRCT2Touch)
target_link_options(openrct2-touch PRIVATE
    "LINKER:-ObjC"
    "LINKER:-no_warn_duplicate_libraries")

# Xcode's app link needs every Objective-C entry point from the static UI
# archive. Ninja already pulls the referenced objects through normal linking;
# force-loading there links the archive twice and duplicates Objective-C class
# symbols.
if (CMAKE_GENERATOR STREQUAL "Xcode")
    target_link_options(openrct2-touch PRIVATE
        "LINKER:-force_load,$<TARGET_FILE:openrct2-ui>")
else ()
    add_custom_command(TARGET openrct2-touch POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${CMAKE_CURRENT_LIST_DIR}/App/Info.plist"
            "$<TARGET_BUNDLE_DIR:openrct2-touch>/Info.plist"
        COMMAND "${ROOT_DIR}/scripts/compile-ios-assets.sh"
            "$<TARGET_BUNDLE_DIR:openrct2-touch>"
            "${OPENRCT2_IOS_PLATFORM}"
        COMMENT "Installing Info.plist and compiling the iOS app icon catalog")
endif ()

set_target_properties(openrct2-touch PROPERTIES
    OUTPUT_NAME "OpenRCT2Touch"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/App/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "${OPENRCT2_IOS_CODE_SIGNING_ALLOWED}"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${OPENRCT2_IOS_DEVELOPMENT_TEAM}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.chrissotraidis.openrct2touch"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "27.0")

if (CMAKE_GENERATOR STREQUAL "Xcode")
    # A signed bundle must not be modified after Xcode's CodeSign phase. Attach
    # the redistributable engine asset copy to the app target so it runs first.
    add_custom_command(TARGET openrct2-touch PRE_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${ROOT_DIR}/assets/engine"
        "$<TARGET_BUNDLE_DIR:openrct2-touch>"
        COMMAND "${ROOT_DIR}/scripts/stage-ios-licenses.sh"
        "$<TARGET_BUNDLE_DIR:openrct2-touch>"
        "${VCPKG_INSTALLED_DIR}"
        "${VCPKG_TARGET_TRIPLET}"
        COMMENT "Staging redistributable OpenRCT2 engine assets before signing")
    if (OPENRCT2_BUNDLE_LOCAL_RCT2)
        add_custom_command(TARGET openrct2-touch PRE_BUILD
            COMMAND "${ROOT_DIR}/scripts/bundle-local-rct2.sh"
            "$<TARGET_BUNDLE_DIR:openrct2-touch>"
            COMMENT "Copying personal RCT2 data into the local app before signing")
    endif ()
    add_custom_target(openrct2-touch-stage DEPENDS openrct2-touch)
else ()
    add_custom_target(openrct2-touch-stage
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
            "${ROOT_DIR}/assets/engine"
            "$<TARGET_BUNDLE_DIR:openrct2-touch>"
        COMMAND "${ROOT_DIR}/scripts/stage-ios-licenses.sh"
            "$<TARGET_BUNDLE_DIR:openrct2-touch>"
            "${VCPKG_INSTALLED_DIR}"
            "${VCPKG_TARGET_TRIPLET}"
        COMMENT "Staging redistributable OpenRCT2 engine assets"
        DEPENDS openrct2-touch)
endif ()
