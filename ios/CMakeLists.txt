# OpenRCT2 Touch iPad application shell.

if (NOT TARGET SDL2::SDL2main)
    message(FATAL_ERROR "SDL2 did not provide the UIKit SDL2main target")
endif ()

add_executable(openrct2-touch MACOSX_BUNDLE
    "${CMAKE_CURRENT_LIST_DIR}/App/AppLifecycle.iOS.mm"
    "${CMAKE_CURRENT_LIST_DIR}/platform/RCT2Importer.iOS.mm")

option(OPENRCT2_IOS_CODE_SIGNING "Allow Xcode to sign the iPadOS app" OFF)
set(OPENRCT2_IOS_DEVELOPMENT_TEAM "" CACHE STRING "Apple development team used only for a signed iPadOS build")

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
    OpenRCT2::openrct2-ui)
target_link_options(openrct2-touch PRIVATE
    "LINKER:-ObjC"
    "LINKER:-force_load,$<TARGET_FILE:openrct2-ui>"
    "LINKER:-no_warn_duplicate_libraries")

set_target_properties(openrct2-touch PROPERTIES
    OUTPUT_NAME "OpenRCT2Touch"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/App/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "${OPENRCT2_IOS_CODE_SIGNING_ALLOWED}"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${OPENRCT2_IOS_DEVELOPMENT_TEAM}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.openrct2.touch"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2")

if (CMAKE_GENERATOR STREQUAL "Xcode")
    # A signed bundle must not be modified after Xcode's CodeSign phase. Attach
    # the redistributable engine asset copy to the app target so it runs first.
    add_custom_command(TARGET openrct2-touch PRE_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${ROOT_DIR}/assets/engine"
        "$<TARGET_BUNDLE_DIR:openrct2-touch>"
        COMMENT "Staging redistributable OpenRCT2 engine assets before signing")
    add_custom_target(openrct2-touch-stage DEPENDS openrct2-touch)
else ()
    add_custom_target(openrct2-touch-stage
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
            "${ROOT_DIR}/assets/engine"
            "$<TARGET_BUNDLE_DIR:openrct2-touch>"
        COMMENT "Staging redistributable OpenRCT2 engine assets"
        DEPENDS openrct2-touch)
endif ()
